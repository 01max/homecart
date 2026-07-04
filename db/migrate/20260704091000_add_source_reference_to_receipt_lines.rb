class AddSourceReferenceToReceiptLines < ActiveRecord::Migration[8.1]
  def change
    add_column :receipt_lines, :source_reference, :text
  end
end
