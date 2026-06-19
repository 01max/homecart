class CreateComparisonUnits < ActiveRecord::Migration[8.1]
  def change
    create_table :comparison_units, id: :uuid do |t|
      t.string :name, null: false
      t.string :symbol, null: false
      t.string :normalized_name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :comparison_units, :normalized_name, unique: true
    add_index :comparison_units, :slug, unique: true
    add_index :comparison_units, :symbol, unique: true
  end
end
