class CreateManufacturers < ActiveRecord::Migration[8.1]
  def change
    create_table :manufacturers, id: :uuid do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :manufacturers, :normalized_name, unique: true
    add_index :manufacturers, :slug, unique: true
  end
end
