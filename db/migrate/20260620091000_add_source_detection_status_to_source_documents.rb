class AddSourceDetectionStatusToSourceDocuments < ActiveRecord::Migration[8.1]
  def up
    create_enum :source_detection_status, %w[ pending classified needs_classification ]

    add_column :source_documents,
               :source_detection_status,
               :enum,
               enum_type: :source_detection_status,
               null: false,
               default: "pending"

    execute <<~SQL.squish
      UPDATE source_documents
      SET source_detection_status = 'classified'::source_detection_status
    SQL

    backfill_manual_detection_records

    change_column_null :source_documents, :store_id, true
    change_column_null :source_documents, :parser_format, true

    add_check_constraint :source_documents,
                         "source_detection_status <> 'classified' OR " \
                           "(store_id IS NOT NULL AND parser_format IS NOT NULL)",
                         name: "source_documents_classified_source_present"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def backfill_manual_detection_records
    execute <<~SQL.squish
      INSERT INTO source_document_detections (
        source_document_id,
        text_extraction_id,
        status,
        parser_format,
        parser_confidence,
        store_id,
        store_confidence,
        evidence,
        created_at,
        updated_at
      )
      SELECT
        source_documents.id,
        latest_text_extractions.id,
        'classified'::source_document_detection_status,
        source_documents.parser_format,
        'manual'::source_document_detection_confidence,
        source_documents.store_id,
        'manual'::source_document_detection_confidence,
        jsonb_build_array(
          jsonb_build_object(
            'code', 'manual_backfill',
            'migration', '20260620091000'
          )
        ),
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM source_documents
      JOIN LATERAL (
        SELECT text_extractions.id
        FROM text_extractions
        WHERE text_extractions.source_document_id = source_documents.id
          AND text_extractions.success = TRUE
        ORDER BY text_extractions.ran_at DESC, text_extractions.created_at DESC
        LIMIT 1
      ) latest_text_extractions ON TRUE
    SQL
  end
end
