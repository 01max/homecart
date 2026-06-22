class HardenSourceDocumentDetections < ActiveRecord::Migration[8.1]
  def up
    add_check_constraint :source_document_detections,
                         "status <> 'classified' OR " \
                           "(store_id IS NOT NULL AND parser_format IS NOT NULL)",
                         name: "source_document_detections_classified_source_present"

    add_check_constraint :source_document_detections,
                         "(parser_format IS NULL AND parser_confidence = 'none') OR " \
                           "(parser_format IS NOT NULL AND parser_confidence <> 'none')",
                         name: "source_document_detections_parser_confidence_consistent"

    add_check_constraint :source_document_detections,
                         "(store_id IS NULL AND store_confidence = 'none') OR " \
                           "(store_id IS NOT NULL AND store_confidence <> 'none')",
                         name: "source_document_detections_store_confidence_consistent"

    execute <<~SQL
      CREATE FUNCTION prevent_source_document_detection_evidence_update()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'source_document_detections evidence columns are immutable';
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE TRIGGER source_document_detections_evidence_immutable
      BEFORE UPDATE OF source_document_id,
                       text_extraction_id,
                       status,
                       parser_format,
                       parser_confidence,
                       store_id,
                       store_confidence,
                       evidence
      ON source_document_detections
      FOR EACH ROW
      EXECUTE FUNCTION prevent_source_document_detection_evidence_update();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS source_document_detections_evidence_immutable ON source_document_detections"
    execute "DROP FUNCTION IF EXISTS prevent_source_document_detection_evidence_update()"

    remove_check_constraint :source_document_detections,
                            name: "source_document_detections_store_confidence_consistent"
    remove_check_constraint :source_document_detections,
                            name: "source_document_detections_parser_confidence_consistent"
    remove_check_constraint :source_document_detections,
                            name: "source_document_detections_classified_source_present"
  end
end
