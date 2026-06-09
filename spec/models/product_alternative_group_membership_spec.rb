require "rails_helper"

RSpec.describe ProductAlternativeGroupMembership do
  it "belongs to an alternative group and product variant" do
    group = create(:product_alternative_group)
    variant = create(:product_variant, product: create(:product, category: group.category))
    membership = create(:product_alternative_group_membership, product_alternative_group: group, product_variant: variant)

    expect(membership.product_alternative_group).to eq(group)
    expect(membership.product_variant).to eq(variant)
  end

  it "declares equivalence levels" do
    membership = build(:product_alternative_group_membership, equivalence: "different_size")

    expect(described_class.equivalences.keys).to contain_exactly("equivalent", "comparable_size", "different_size")
    expect(membership.different_size?).to be(true)
  end

  it "requires a unique variant within an alternative group" do
    membership = create(:product_alternative_group_membership)
    duplicate = build(
      :product_alternative_group_membership,
      product_alternative_group: membership.product_alternative_group,
      product_variant: membership.product_variant
    )

    expect(duplicate).not_to be_valid
  end

  it "allows the same variant in another alternative group" do
    membership = create(:product_alternative_group_membership)
    other_group = create(:product_alternative_group, category: membership.product_variant.product.category)
    duplicate = build(
      :product_alternative_group_membership,
      product_alternative_group: other_group,
      product_variant: membership.product_variant
    )

    expect(duplicate).to be_valid
  end
end
