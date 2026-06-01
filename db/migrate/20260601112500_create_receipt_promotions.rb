class CreateReceiptPromotions < ActiveRecord::Migration[8.1]
  def change
    create_enum :receipt_promotion_unit, %w[ euro_cents vignette_count ]
    create_enum :receipt_promotion_kind, %w[ loyalty_credit immediate_discount coupon points_accrual ]
    create_enum :receipt_promotion_linking_method, %w[ parser_inferred user_confirmed unallocated ]

    create_table :receipt_promotions do |t|
      t.references :receipt, null: false, foreign_key: true
      t.string :program, null: false
      t.enum :unit, enum_type: :receipt_promotion_unit, null: false
      t.integer :delta, null: false
      t.text :label
      t.references :linked_line, foreign_key: { to_table: :receipt_lines }
      t.enum :kind, enum_type: :receipt_promotion_kind, null: false
      t.enum :linking_method, enum_type: :receipt_promotion_linking_method, null: false

      t.timestamps
    end

    add_check_constraint(
      :receipt_promotions,
      <<~SQL.squish,
        (
          linked_line_id IS NULL AND linking_method = 'unallocated'
        ) OR (
          linked_line_id IS NOT NULL AND linking_method IN ('parser_inferred', 'user_confirmed')
        )
      SQL
      name: "receipt_promotions_linking_method_matches_link"
    )
  end
end
