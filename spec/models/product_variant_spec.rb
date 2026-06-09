require "rails_helper"

RSpec.describe ProductVariant do
  it "belongs to a product and comparison unit" do
    product = create(:product)
    comparison_unit = create(:comparison_unit)
    variant = create(:product_variant, product: product, comparison_unit: comparison_unit)

    expect(variant.product).to eq(product)
    expect(variant.comparison_unit).to eq(comparison_unit)
  end

  it "can omit barcode and comparison unit details" do
    variant = build(:product_variant, :without_barcode, :without_comparison_unit)

    expect(variant).to be_valid
  end

  it "belongs to alternative groups through memberships" do
    variant = create(:product_variant)
    group = create(:product_alternative_group, category: variant.product.category)
    create(:product_alternative_group_membership, product_alternative_group: group, product_variant: variant)

    expect(variant.product_alternative_groups).to contain_exactly(group)
  end

  it "requires normalized names to be unique within a product" do
    variant = create(:product_variant, normalized_name: "12-x-90g")
    duplicate = build(:product_variant, product: variant.product, normalized_name: "12-x-90g")

    expect(duplicate).not_to be_valid
  end

  it "allows the same normalized name on another product" do
    create(:product_variant, normalized_name: "12-x-90g")
    duplicate = build(:product_variant, normalized_name: "12-x-90g")

    expect(duplicate).to be_valid
  end

  it "requires barcodes to be unique when present" do
    create(:product_variant, barcode: "3760000000001")
    duplicate = build(:product_variant, barcode: "3760000000001")

    expect(duplicate).not_to be_valid
  end

  it "validates package count" do
    variant = build(:product_variant, package_count: 0)

    expect(variant).not_to be_valid
  end

  it "validates quantity value" do
    variant = build(:product_variant, quantity_value: 0)

    expect(variant).not_to be_valid
  end
end
