require "rails_helper"

RSpec.describe ProductAlternativeGroup do
  it "belongs to a category" do
    category = create(:category)
    group = create(:product_alternative_group, category: category)

    expect(group.category).to eq(category)
  end

  it "owns memberships and variants" do
    group = create(:product_alternative_group)
    variant = create(:product_variant, product: create(:product, category: group.category))
    membership = create(:product_alternative_group_membership, product_alternative_group: group, product_variant: variant)

    expect(group.product_alternative_group_memberships).to contain_exactly(membership)
    expect(group.product_variants).to contain_exactly(variant)
  end

  it "requires names to be unique within a category" do
    group = create(:product_alternative_group, name: "Jambon blanc")
    duplicate = build(:product_alternative_group, category: group.category, name: "Jambon blanc")

    expect(duplicate).not_to be_valid
  end

  it "allows the same name in another category" do
    create(:product_alternative_group, name: "Jambon blanc")
    duplicate = build(:product_alternative_group, name: "Jambon blanc")

    expect(duplicate).to be_valid
  end
end
