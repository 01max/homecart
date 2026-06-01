class CreateReceiptLines < ActiveRecord::Migration[8.1]
  def change
    create_enum :receipt_line_unit_of_measure, %w[ piece kg g l ml ]
    create_enum :receipt_line_kind, %w[ item fee discount ]

    create_table :receipt_lines do |t|
      t.references :receipt, null: false, foreign_key: true
      t.integer :position, null: false
      t.text :raw_text, null: false
      t.text :label, null: false
      t.boolean :label_truncated, null: false, default: false
      t.decimal :quantity, precision: 10, scale: 3, null: false, default: "1.0"
      t.enum :unit_of_measure, enum_type: :receipt_line_unit_of_measure, null: false, default: "piece"
      t.integer :unit_price_cents
      t.integer :total_cents, null: false
      t.integer :vat_rate_bp
      t.boolean :tr_eligible, null: false, default: false
      t.text :section_label
      t.enum :kind, enum_type: :receipt_line_kind, null: false, default: "item"

      t.timestamps
    end

    add_index :receipt_lines, [ :receipt_id, :position ], unique: true
  end
end
