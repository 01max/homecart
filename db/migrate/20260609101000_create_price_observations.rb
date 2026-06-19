class CreatePriceObservations < ActiveRecord::Migration[8.1]
  def change
    create_enum :price_observation_source, %w[ receipt_line ]

    create_table :price_observations, id: :uuid do |t|
      t.references :receipt_line_match,
                   type: :uuid,
                   null: false,
                   foreign_key: true,
                   index: { unique: true }
      t.references :receipt_line,
                   type: :uuid,
                   null: false,
                   foreign_key: true,
                   index: { unique: true }
      t.references :product_variant, type: :uuid, null: false, foreign_key: true
      t.references :store, type: :uuid, null: false, foreign_key: true
      t.datetime :observed_at, null: false
      t.decimal :purchased_quantity, precision: 10, scale: 3, null: false
      t.enum :purchased_unit, enum_type: :receipt_line_unit_of_measure, null: false
      t.integer :total_cents, null: false
      t.integer :pack_unit_price_cents, null: false
      t.references :comparison_unit, type: :uuid, null: true, foreign_key: true
      t.integer :comparison_unit_price_cents
      t.enum :source, enum_type: :price_observation_source, null: false

      t.timestamps
    end

    add_index :price_observations,
              [ :product_variant_id, :store_id, :observed_at ],
              name: "index_price_observations_on_variant_store_observed_at"
    add_index :price_observations,
              [ :store_id, :observed_at ],
              name: "index_price_observations_on_store_observed_at"
    add_check_constraint :price_observations,
                         "purchased_quantity > 0",
                         name: "price_observations_purchased_quantity_positive"
    add_check_constraint :price_observations,
                         "total_cents >= 0",
                         name: "price_observations_total_cents_non_negative"
    add_check_constraint :price_observations,
                         "pack_unit_price_cents >= 0",
                         name: "price_observations_pack_unit_price_non_negative"
    add_check_constraint :price_observations,
                         "comparison_unit_price_cents IS NULL OR comparison_unit_price_cents >= 0",
                         name: "price_observations_comparison_unit_price_non_negative"
    add_check_constraint :price_observations,
                         <<~SQL.squish,
                           (
                             comparison_unit_id IS NULL
                             AND comparison_unit_price_cents IS NULL
                           )
                           OR
                           (
                             comparison_unit_id IS NOT NULL
                             AND comparison_unit_price_cents IS NOT NULL
                           )
                         SQL
                         name: "price_observations_comparison_unit_pairing"
  end
end
