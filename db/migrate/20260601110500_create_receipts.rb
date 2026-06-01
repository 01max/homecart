class CreateReceipts < ActiveRecord::Migration[8.1]
  def change
    create_enum :receipt_parser_status, %w[ parsed needs_review reviewed ]

    create_table :receipts do |t|
      t.references :store, null: false, foreign_key: true
      t.references :source_document, null: false, foreign_key: true
      t.references :text_extraction, null: false, foreign_key: true
      t.enum :parser_format, enum_type: :parser_format, null: false
      t.datetime :purchased_at
      t.string :register_number
      t.string :ticket_number
      t.string :cashier_code
      t.integer :total_cents
      t.integer :declared_article_count
      t.enum :parser_status, enum_type: :receipt_parser_status, null: false, default: "needs_review"
      t.jsonb :parser_warnings, null: false, default: []

      t.timestamps
    end

    change_column_comment(
      :receipts,
      :purchased_at,
      from: nil,
      to: "Wall-clock local transaction time, stored as printed or implied with no timezone offset applied. " \
          "Drive and Click & Collect receipts use the PDF order-confirmation time."
    )

    add_index(
      :receipts,
      [ :store_id, :register_number, :ticket_number, :purchased_at ],
      unique: true,
      where: "store_id IS NOT NULL AND register_number IS NOT NULL " \
             "AND ticket_number IS NOT NULL AND purchased_at IS NOT NULL",
      name: "index_receipts_on_store_register_ticket_purchased_at"
    )

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          COMMENT ON INDEX index_receipts_on_store_register_ticket_purchased_at IS
          'Soft duplicate guard. Intentionally excludes rows where any composite receipt identifier is NULL;
          source_documents.content_hash is the hard re-upload guard for exact duplicate files.'
        SQL
      end

      dir.down do
        execute "COMMENT ON INDEX index_receipts_on_store_register_ticket_purchased_at IS NULL"
      end
    end
  end
end
