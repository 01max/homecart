class AddProductVariantPresenceConstraintToReceiptLineMatches < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :receipt_line_matches,
                         <<~SQL.squish,
                           (
                             status = 'ignored'
                             AND product_variant_id IS NULL
                           )
                           OR
                           (
                             status IN ('suggested', 'confirmed', 'rejected')
                             AND product_variant_id IS NOT NULL
                           )
                         SQL
                         name: "receipt_line_matches_product_variant_presence"
  end
end
