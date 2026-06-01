class AddEvidenceImmutabilityGuards < ActiveRecord::Migration[8.1]
  def up
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

  def down
    execute "DROP TRIGGER IF EXISTS text_extractions_evidence_immutable ON text_extractions"
    execute "DROP FUNCTION IF EXISTS prevent_text_extraction_evidence_update()"
    execute "DROP TRIGGER IF EXISTS source_documents_evidence_immutable ON source_documents"
    execute "DROP FUNCTION IF EXISTS prevent_source_document_evidence_update()"
  end
end
