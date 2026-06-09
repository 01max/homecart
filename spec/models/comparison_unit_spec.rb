require "rails_helper"

RSpec.describe ComparisonUnit do
  it "owns product variants" do
    comparison_unit = create(:comparison_unit)
    variant = create(:product_variant, comparison_unit: comparison_unit)

    expect(comparison_unit.product_variants).to contain_exactly(variant)
  end

  it "requires a symbol" do
    comparison_unit = build(:comparison_unit, symbol: nil)

    expect(comparison_unit).not_to be_valid
  end

  it "requires a unique symbol" do
    create(:comparison_unit, symbol: "slice")
    duplicate = build(:comparison_unit, symbol: "slice")

    expect(duplicate).not_to be_valid
  end

  it "requires a unique normalized name" do
    create(:comparison_unit, normalized_name: "gram")
    duplicate = build(:comparison_unit, normalized_name: "gram")

    expect(duplicate).not_to be_valid
  end
end
