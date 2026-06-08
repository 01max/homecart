class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories, id: :uuid do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :slug, null: false
      t.references :parent, type: :uuid, null: true, foreign_key: { to_table: :categories }

      t.timestamps
    end

    add_index :categories, :normalized_name, unique: true
    add_index :categories, :slug, unique: true
    add_check_constraint :categories, "parent_id IS NULL OR parent_id <> id", name: "categories_parent_not_self"
  end
end
