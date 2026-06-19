class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products, id: :uuid do |t|
      t.references :product_brand, type: :uuid, null: false, foreign_key: true
      t.references :manufacturer, type: :uuid, null: true, foreign_key: true
      t.references :category, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :products, [ :product_brand_id, :category_id, :normalized_name ],
              unique: true,
              name: "index_products_on_brand_category_normalized_name"
    add_index :products, [ :product_brand_id, :category_id, :slug ],
              unique: true,
              name: "index_products_on_brand_category_slug"
  end
end
