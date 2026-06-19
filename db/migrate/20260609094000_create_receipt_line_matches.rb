class CreateReceiptLineMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :receipt_line_matches, id: :uuid do |t|
      t.references :receipt_line, type: :uuid, null: false, foreign_key: true
      t.references :product_variant, type: :uuid, null: true, foreign_key: true
      t.enum :status, enum_type: :receipt_line_match_status, null: false
      t.enum :source, enum_type: :receipt_line_match_source, null: false
      t.decimal :confidence, precision: 5, scale: 4
      t.text :label_snapshot, null: false
      t.datetime :decided_at

      t.timestamps
    end

    add_index :receipt_line_matches, [ :receipt_line_id, :status ]
    add_index :receipt_line_matches, [ :product_variant_id, :status ]
    add_check_constraint :receipt_line_matches,
                         "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)",
                         name: "receipt_line_matches_confidence_probability"
  end
end
