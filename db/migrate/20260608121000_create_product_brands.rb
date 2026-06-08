class CreateProductBrands < ActiveRecord::Migration[8.1]
  def change
    create_table :product_brands, id: :uuid do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :slug, null: false
      t.references :retail_brand, type: :uuid, null: true, foreign_key: true

      t.timestamps
    end

    add_index :product_brands, :normalized_name, unique: true
    add_index :product_brands, :slug, unique: true
  end
end
