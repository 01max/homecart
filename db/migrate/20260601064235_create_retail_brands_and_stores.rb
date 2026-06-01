class CreateRetailBrandsAndStores < ActiveRecord::Migration[8.1]
  def change
    create_enum :store_channel, %w[ physical drive click_collect ]

    create_table :retail_brands do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.jsonb :aliases, null: false, default: []

      t.timestamps
    end

    add_index :retail_brands, :slug, unique: true

    create_table :stores do |t|
      t.references :retail_brand, null: false, foreign_key: true
      t.string :location_name, null: false
      t.enum :channel, enum_type: :store_channel, null: false
      t.text :address
      t.jsonb :identifiers, null: false, default: {}

      t.timestamps
    end

    add_index :stores, [ :retail_brand_id, :location_name, :channel ], unique: true
  end
end
