class CreateProductVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :product_variants, id: :uuid do |t|
      t.references :product, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :slug, null: false
      t.integer :package_count
      t.decimal :quantity_value, precision: 10, scale: 3
      t.references :comparison_unit, type: :uuid, null: true, foreign_key: true
      t.string :barcode

      t.timestamps
    end

    add_index :product_variants, [ :product_id, :normalized_name ], unique: true
    add_index :product_variants, [ :product_id, :slug ], unique: true
    add_index :product_variants, :barcode, unique: true, where: "barcode IS NOT NULL"
    add_index :product_variants, :normalized_name,
              using: :gin,
              opclass: :gin_trgm_ops,
              name: "index_product_variants_on_normalized_name_trgm"
    add_check_constraint :product_variants,
                         "package_count IS NULL OR package_count > 0",
                         name: "product_variants_package_count_positive"
    add_check_constraint :product_variants,
                         "quantity_value IS NULL OR quantity_value > 0",
                         name: "product_variants_quantity_value_positive"
  end
end
