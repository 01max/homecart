require "rails_helper"

RSpec.describe ProductCatalog::CreateVariantService do
  def call_service(**overrides)
    described_class.call(
      product_brand_name: "Bio Village",
      product_name: "Compotes pomme",
      variant_name: "12 x 90g",
      category_name: "Compotes",
      **overrides
    )
  end

  def create_provided_records
    {
      category: create(:category, name: "Gouter"),
      manufacturer: create(:manufacturer, name: "Existing Manufacturer"),
      comparison_unit: create(:comparison_unit, name: "Slice", symbol: "slice")
    }
  end

  def call_full_chain_service(retail_brand)
    call_service(
      retail_brand: retail_brand,
      manufacturer_name: "Compotes Co",
      comparison_unit_name: "Gram",
      comparison_unit_symbol: "g",
      package_count: 12,
      quantity_value: 90,
      barcode: "3760000000001"
    )
  end

  def call_with_provided_records(records)
    call_service(
      category: records.fetch(:category),
      manufacturer: records.fetch(:manufacturer),
      comparison_unit: records.fetch(:comparison_unit),
      category_name: "Ignored Category",
      manufacturer_name: "Ignored Manufacturer",
      comparison_unit_name: "Ignored Unit",
      comparison_unit_symbol: "ignored"
    )
  end

  def call_normalized_duplicate_service
    described_class.call(
      product_brand_name: "BIO Villagé",
      product_name: "Compotés Pomme",
      variant_name: "12 X 90G",
      category_name: "Compotés"
    )
  end

  def expect_full_catalogue_chain(result, retail_brand)
    expect(result.product_brand).to have_attributes(name: "Bio Village", retail_brand: retail_brand)
    expect(result.manufacturer).to have_attributes(name: "Compotes Co")
    expect(result.category).to have_attributes(name: "Compotes")
    expect(result.comparison_unit).to have_attributes(name: "Gram", symbol: "g")
    expect(result.product).to have_attributes(product_brand: result.product_brand, category: result.category)
    expect(result.variant).to have_attributes(product: result.product, barcode: "3760000000001")
  end

  def expect_reused_catalogue_chain(second_result, first_result)
    expect(second_result.product_brand).to eq(first_result.product_brand)
    expect(second_result.category).to eq(first_result.category)
    expect(second_result.product).to eq(first_result.product)
    expect(second_result.variant).to eq(first_result.variant)
    expect(second_result.comparison_unit).to eq(first_result.comparison_unit)
  end

  it "creates the catalogue chain for a concrete variant" do
    retail_brand = create(:retail_brand)
    result = call_full_chain_service(retail_brand)

    expect_full_catalogue_chain(result, retail_brand)
  end

  it "reuses existing catalogue records on repeated calls" do
    first_result = call_service(comparison_unit_name: "Gram", comparison_unit_symbol: "g")

    expect do
      second_result = call_service(comparison_unit_name: "Gram", comparison_unit_symbol: "g")

      expect_reused_catalogue_chain(second_result, first_result)
    end.not_to change(ProductVariant, :count)
  end

  it "prevents duplicates when names normalize to existing catalogue records" do
    first_result = call_service

    expect do
      duplicate_result = call_normalized_duplicate_service

      expect_reused_catalogue_chain(duplicate_result, first_result)
    end.not_to change(ProductVariant, :count)
  end

  it "creates a product without manufacturer and a variant without barcode or comparison unit" do
    result = call_service(manufacturer_name: nil, barcode: nil)

    expect(result.manufacturer).to be_nil
    expect(result.comparison_unit).to be_nil
    expect(result.product.manufacturer).to be_nil
    expect(result.variant.barcode).to be_nil
  end

  it "reuses provided category, manufacturer, and comparison unit records" do
    records = create_provided_records
    result = call_with_provided_records(records)

    expect(result).to have_attributes(
      category: records.fetch(:category),
      manufacturer: records.fetch(:manufacturer),
      comparison_unit: records.fetch(:comparison_unit)
    )
  end

  it "requires a category and rolls back the workflow" do
    expect do
      expect do
        call_service(category_name: nil)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end.not_to change(ProductBrand, :count)
  end
end
