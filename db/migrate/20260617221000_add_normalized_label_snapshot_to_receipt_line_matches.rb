class AddNormalizedLabelSnapshotToReceiptLineMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :receipt_line_matches, :normalized_label_snapshot, :string

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE receipt_line_matches
          SET normalized_label_snapshot = btrim(regexp_replace(lower(unaccent(label_snapshot)), '[^a-z0-9]+', ' ', 'g'))
        SQL
      end
    end

    change_column_null :receipt_line_matches, :normalized_label_snapshot, false
    add_index :receipt_line_matches,
              [ :status, :normalized_label_snapshot ],
              name: "index_receipt_line_matches_on_status_normalized_label"
  end
end
