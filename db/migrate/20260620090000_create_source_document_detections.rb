class CreateSourceDocumentDetections < ActiveRecord::Migration[8.1]
  def change
    create_enum :source_document_detection_status, %w[ classified needs_classification ]
    create_enum :source_document_detection_confidence, %w[ none low high manual ]

    create_table :source_document_detections, id: :uuid do |t|
      t.references :source_document, type: :uuid, null: false, foreign_key: true
      t.references :text_extraction, type: :uuid, null: false, foreign_key: true
      t.enum :status, enum_type: :source_document_detection_status, null: false
      t.enum :parser_format, enum_type: :parser_format
      t.enum :parser_confidence,
             enum_type: :source_document_detection_confidence,
             null: false,
             default: "none"
      t.references :store, type: :uuid, foreign_key: true
      t.enum :store_confidence,
             enum_type: :source_document_detection_confidence,
             null: false,
             default: "none"
      t.jsonb :evidence, null: false, default: []

      t.timestamps
    end

    add_index :source_document_detections, [ :source_document_id, :created_at ]
    add_index :source_document_detections, [ :text_extraction_id, :created_at ]
    add_check_constraint :source_document_detections,
                         "jsonb_typeof(evidence) = 'array'",
                         name: "source_document_detections_evidence_array"
  end
end
