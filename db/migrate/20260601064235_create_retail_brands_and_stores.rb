class CreateRetailBrandsAndStores < ActiveRecord::Migration[8.1]
  STORE_CHANNELS = %w[ physical drive click_collect ].freeze

  def change
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
      t.string :channel, null: false
      t.text :address
      t.jsonb :identifiers, null: false, default: {}

      t.timestamps
    end

    add_index :stores, [ :retail_brand_id, :location_name, :channel ], unique: true
    add_check_constraint :stores, "channel IN (#{STORE_CHANNELS.map { |channel| quote(channel) }.join(", ")})",
                         name: "stores_channel_check"
  end
end
