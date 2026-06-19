class CreateProductAlternativeGroups < ActiveRecord::Migration[8.1]
  def change
    create_enum :product_alternative_equivalence, %w[ equivalent comparable_size different_size ]

    create_table :product_alternative_groups, id: :uuid do |t|
      t.references :category, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :product_alternative_groups, [ :category_id, :name ], unique: true

    create_table :product_alternative_group_memberships, id: :uuid do |t|
      t.references :product_alternative_group,
                   type: :uuid,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_alt_group_memberships_on_group_id" }
      t.references :product_variant,
                   type: :uuid,
                   null: false,
                   foreign_key: true,
                   index: { name: "index_alt_group_memberships_on_variant_id" }
      t.enum :equivalence, enum_type: :product_alternative_equivalence, null: false

      t.timestamps
    end

    add_index :product_alternative_group_memberships,
              [ :product_alternative_group_id, :product_variant_id ],
              unique: true,
              name: "index_alt_group_memberships_on_group_and_variant"
  end
end
