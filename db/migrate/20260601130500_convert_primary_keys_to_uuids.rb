class ConvertPrimaryKeysToUuids < ActiveRecord::Migration[8.1]
  ID_TABLES = %w[
    active_storage_blobs
    active_storage_attachments
    active_storage_variant_records
    retail_brands
    stores
    source_documents
    text_extractions
    receipts
    receipt_lines
    receipt_promotions
    receipt_payments
  ].freeze

  UUID_REFERENCES = [
    [ "active_storage_attachments", "blob", "active_storage_blobs", false ],
    [ "active_storage_variant_records", "blob", "active_storage_blobs", false ],
    [ "stores", "retail_brand", "retail_brands", false ],
    [ "source_documents", "store", "stores", false ],
    [ "text_extractions", "source_document", "source_documents", false ],
    [ "receipts", "store", "stores", false ],
    [ "receipts", "source_document", "source_documents", false ],
    [ "receipts", "text_extraction", "text_extractions", false ],
    [ "receipt_lines", "receipt", "receipts", false ],
    [ "receipt_promotions", "receipt", "receipts", false ],
    [ "receipt_promotions", "linked_line", "receipt_lines", true ],
    [ "receipt_payments", "receipt", "receipts", false ]
  ].freeze

  INDEX_NAMES = %w[
    index_active_storage_attachments_on_blob_id
    index_active_storage_attachments_uniqueness
    index_active_storage_blobs_on_key
    index_active_storage_variant_records_uniqueness
    index_receipt_lines_on_receipt_id
    index_receipt_lines_on_receipt_id_and_position
    index_receipt_payments_on_receipt_id
    index_receipt_payments_on_receipt_id_and_position
    index_receipt_promotions_on_linked_line_id
    index_receipt_promotions_on_receipt_id
    index_receipts_on_source_document_id
    index_receipts_on_store_id
    index_receipts_on_store_register_ticket_purchased_at
    index_receipts_on_text_extraction_id
    index_retail_brands_on_slug
    index_source_documents_on_content_hash
    index_source_documents_on_store_id
    index_stores_on_retail_brand_id
    index_stores_on_retail_brand_id_and_location_name_and_channel
    index_text_extractions_on_source_document_id
  ].freeze

  FK_CONSTRAINTS = %w[
    fk_rails_01cb4412a8
    fk_rails_01d25a15c8
    fk_rails_0b2f6f5e69
    fk_rails_479c8da4db
    fk_rails_4e2f966342
    fk_rails_550c459587
    fk_rails_611ac14192
    fk_rails_848b654367
    fk_rails_993965df05
    fk_rails_c3b3935057
    fk_rails_e0f65dc69f
    fk_rails_f78688ae38
  ].freeze

  def up
    enable_extension "pgcrypto"

    drop_evidence_immutability_triggers
    add_uuid_primary_keys
    add_uuid_references
    add_uuid_polymorphic_record_reference
    drop_constraints
    swap_uuid_columns
    recreate_constraints
    recreate_evidence_immutability_triggers
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def drop_evidence_immutability_triggers
    execute "DROP TRIGGER IF EXISTS text_extractions_evidence_immutable ON text_extractions"
    execute "DROP FUNCTION IF EXISTS prevent_text_extraction_evidence_update()"
    execute "DROP TRIGGER IF EXISTS source_documents_evidence_immutable ON source_documents"
    execute "DROP FUNCTION IF EXISTS prevent_source_document_evidence_update()"
  end

  def add_uuid_primary_keys
    ID_TABLES.each do |table_name|
      execute "ALTER TABLE #{table_name} ADD COLUMN uuid_id uuid"
      execute "UPDATE #{table_name} SET uuid_id = gen_random_uuid()"
      execute "ALTER TABLE #{table_name} ALTER COLUMN uuid_id SET NOT NULL"
      execute "ALTER TABLE #{table_name} ALTER COLUMN uuid_id SET DEFAULT gen_random_uuid()"
    end
  end

  def add_uuid_references
    UUID_REFERENCES.each do |table_name, reference_name, referenced_table_name, nullable|
      execute "ALTER TABLE #{table_name} ADD COLUMN #{reference_name}_uuid uuid"
      execute <<~SQL.squish
        UPDATE #{table_name}
        SET #{reference_name}_uuid = #{referenced_table_name}.uuid_id
        FROM #{referenced_table_name}
        WHERE #{table_name}.#{reference_name}_id = #{referenced_table_name}.id
      SQL
      execute "ALTER TABLE #{table_name} ALTER COLUMN #{reference_name}_uuid SET NOT NULL" unless nullable
    end
  end

  def add_uuid_polymorphic_record_reference
    execute "ALTER TABLE active_storage_attachments ADD COLUMN record_uuid uuid"

    {
      "Receipt" => "receipts",
      "ReceiptLine" => "receipt_lines",
      "ReceiptPayment" => "receipt_payments",
      "ReceiptPromotion" => "receipt_promotions",
      "RetailBrand" => "retail_brands",
      "SourceDocument" => "source_documents",
      "Store" => "stores",
      "TextExtraction" => "text_extractions"
    }.each do |record_type, table_name|
      execute <<~SQL.squish
        UPDATE active_storage_attachments
        SET record_uuid = #{table_name}.uuid_id
        FROM #{table_name}
        WHERE active_storage_attachments.record_type = #{quote(record_type)}
          AND active_storage_attachments.record_id = #{table_name}.id
      SQL
    end

    execute "ALTER TABLE active_storage_attachments ALTER COLUMN record_uuid SET NOT NULL"
  end

  def drop_constraints
    FK_CONSTRAINTS.each do |constraint_name|
      execute "ALTER TABLE #{table_for_constraint(constraint_name)} DROP CONSTRAINT IF EXISTS #{constraint_name}"
    end

    INDEX_NAMES.each do |index_name|
      execute "DROP INDEX IF EXISTS #{index_name}"
    end

    ID_TABLES.each do |table_name|
      execute "ALTER TABLE #{table_name} DROP CONSTRAINT IF EXISTS #{table_name}_pkey"
    end
  end

  def swap_uuid_columns
    UUID_REFERENCES.each do |table_name, reference_name, _referenced_table_name, _nullable|
      execute "ALTER TABLE #{table_name} DROP COLUMN #{reference_name}_id"
      execute "ALTER TABLE #{table_name} RENAME COLUMN #{reference_name}_uuid TO #{reference_name}_id"
    end

    execute "ALTER TABLE active_storage_attachments DROP COLUMN record_id"
    execute "ALTER TABLE active_storage_attachments RENAME COLUMN record_uuid TO record_id"

    ID_TABLES.each do |table_name|
      execute "ALTER TABLE #{table_name} DROP COLUMN id"
      execute "ALTER TABLE #{table_name} RENAME COLUMN uuid_id TO id"
      execute "DROP SEQUENCE IF EXISTS #{table_name}_id_seq"
    end
  end

  def recreate_constraints
    add_primary_keys
    add_indexes
    add_foreign_keys
  end

  def add_primary_keys
    ID_TABLES.each do |table_name|
      execute "ALTER TABLE #{table_name} ADD CONSTRAINT #{table_name}_pkey PRIMARY KEY (id)"
    end
  end

  def add_indexes
    execute "CREATE INDEX index_active_storage_attachments_on_blob_id ON active_storage_attachments (blob_id)"
    execute "CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON active_storage_attachments (record_type, record_id, name, blob_id)"
    execute "CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON active_storage_blobs (key)"
    execute "CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON active_storage_variant_records (blob_id, variation_digest)"
    execute "CREATE UNIQUE INDEX index_retail_brands_on_slug ON retail_brands (slug)"
    execute "CREATE INDEX index_stores_on_retail_brand_id ON stores (retail_brand_id)"
    execute "CREATE UNIQUE INDEX index_stores_on_retail_brand_id_and_location_name_and_channel ON stores (retail_brand_id, location_name, channel)"
    execute "CREATE UNIQUE INDEX index_source_documents_on_content_hash ON source_documents (content_hash)"
    execute "CREATE INDEX index_source_documents_on_store_id ON source_documents (store_id)"
    execute "CREATE INDEX index_text_extractions_on_source_document_id ON text_extractions (source_document_id)"
    execute "CREATE INDEX index_receipts_on_source_document_id ON receipts (source_document_id)"
    execute "CREATE INDEX index_receipts_on_store_id ON receipts (store_id)"
    execute "CREATE INDEX index_receipts_on_text_extraction_id ON receipts (text_extraction_id)"
    execute <<~SQL.squish
      CREATE UNIQUE INDEX index_receipts_on_store_register_ticket_purchased_at
      ON receipts (store_id, register_number, ticket_number, purchased_at)
      WHERE store_id IS NOT NULL
        AND register_number IS NOT NULL
        AND ticket_number IS NOT NULL
        AND purchased_at IS NOT NULL
    SQL
    execute <<~SQL.squish
      COMMENT ON INDEX index_receipts_on_store_register_ticket_purchased_at IS
      'Soft duplicate guard. Intentionally excludes rows where any composite receipt identifier is NULL;
      source_documents.content_hash is the hard re-upload guard for exact duplicate files.'
    SQL
    execute "CREATE INDEX index_receipt_lines_on_receipt_id ON receipt_lines (receipt_id)"
    execute "CREATE UNIQUE INDEX index_receipt_lines_on_receipt_id_and_position ON receipt_lines (receipt_id, position)"
    execute "CREATE INDEX index_receipt_promotions_on_linked_line_id ON receipt_promotions (linked_line_id)"
    execute "CREATE INDEX index_receipt_promotions_on_receipt_id ON receipt_promotions (receipt_id)"
    execute "CREATE INDEX index_receipt_payments_on_receipt_id ON receipt_payments (receipt_id)"
    execute "CREATE UNIQUE INDEX index_receipt_payments_on_receipt_id_and_position ON receipt_payments (receipt_id, position)"
  end

  def add_foreign_keys
    execute "ALTER TABLE active_storage_attachments ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES active_storage_blobs(id)"
    execute "ALTER TABLE active_storage_variant_records ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES active_storage_blobs(id)"
    execute "ALTER TABLE stores ADD CONSTRAINT fk_rails_01d25a15c8 FOREIGN KEY (retail_brand_id) REFERENCES retail_brands(id)"
    execute "ALTER TABLE source_documents ADD CONSTRAINT fk_rails_479c8da4db FOREIGN KEY (store_id) REFERENCES stores(id)"
    execute "ALTER TABLE text_extractions ADD CONSTRAINT fk_rails_848b654367 FOREIGN KEY (source_document_id) REFERENCES source_documents(id)"
    execute "ALTER TABLE receipts ADD CONSTRAINT fk_rails_550c459587 FOREIGN KEY (store_id) REFERENCES stores(id)"
    execute "ALTER TABLE receipts ADD CONSTRAINT fk_rails_4e2f966342 FOREIGN KEY (source_document_id) REFERENCES source_documents(id)"
    execute "ALTER TABLE receipts ADD CONSTRAINT fk_rails_0b2f6f5e69 FOREIGN KEY (text_extraction_id) REFERENCES text_extractions(id)"
    execute "ALTER TABLE receipt_lines ADD CONSTRAINT fk_rails_611ac14192 FOREIGN KEY (receipt_id) REFERENCES receipts(id)"
    execute "ALTER TABLE receipt_promotions ADD CONSTRAINT fk_rails_e0f65dc69f FOREIGN KEY (receipt_id) REFERENCES receipts(id)"
    execute "ALTER TABLE receipt_promotions ADD CONSTRAINT fk_rails_f78688ae38 FOREIGN KEY (linked_line_id) REFERENCES receipt_lines(id)"
    execute "ALTER TABLE receipt_payments ADD CONSTRAINT fk_rails_01cb4412a8 FOREIGN KEY (receipt_id) REFERENCES receipts(id)"
  end

  def recreate_evidence_immutability_triggers
    execute <<~SQL
      CREATE FUNCTION prevent_source_document_evidence_update()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF ROW(OLD.content_hash, OLD.mime_type, OLD.ingested_at)
          IS DISTINCT FROM ROW(NEW.content_hash, NEW.mime_type, NEW.ingested_at) THEN
          RAISE EXCEPTION 'source_documents evidence columns are immutable'
            USING ERRCODE = 'check_violation';
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER source_documents_evidence_immutable
      BEFORE UPDATE OF content_hash, mime_type, ingested_at
      ON source_documents
      FOR EACH ROW
      EXECUTE FUNCTION prevent_source_document_evidence_update();
    SQL

    execute <<~SQL
      CREATE FUNCTION prevent_text_extraction_evidence_update()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF ROW(OLD.source_document_id, OLD.engine, OLD.text, OLD.ran_at, OLD.success, OLD.error_message)
          IS DISTINCT FROM ROW(NEW.source_document_id, NEW.engine, NEW.text, NEW.ran_at, NEW.success, NEW.error_message) THEN
          RAISE EXCEPTION 'text_extractions evidence columns are immutable'
            USING ERRCODE = 'check_violation';
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER text_extractions_evidence_immutable
      BEFORE UPDATE OF source_document_id, engine, text, ran_at, success, error_message
      ON text_extractions
      FOR EACH ROW
      EXECUTE FUNCTION prevent_text_extraction_evidence_update();
    SQL
  end

  def table_for_constraint(constraint_name)
    {
      "fk_rails_01cb4412a8" => "receipt_payments",
      "fk_rails_01d25a15c8" => "stores",
      "fk_rails_0b2f6f5e69" => "receipts",
      "fk_rails_479c8da4db" => "source_documents",
      "fk_rails_4e2f966342" => "receipts",
      "fk_rails_550c459587" => "receipts",
      "fk_rails_611ac14192" => "receipt_lines",
      "fk_rails_848b654367" => "text_extractions",
      "fk_rails_993965df05" => "active_storage_variant_records",
      "fk_rails_c3b3935057" => "active_storage_attachments",
      "fk_rails_e0f65dc69f" => "receipt_promotions",
      "fk_rails_f78688ae38" => "receipt_promotions"
    }.fetch(constraint_name)
  end
end
