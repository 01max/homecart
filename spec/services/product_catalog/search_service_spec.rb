require "rails_helper"

RSpec.describe ProductCatalog::SearchService do
  def result_records_for(query, limit: 20)
    described_class.call(query: query, limit: limit).map(&:record)
  end

  def create_catalogue_variant(product_brand_name:, product_name:, variant_name:)
    product_brand = create(
      :product_brand,
      name: product_brand_name,
      normalized_name: ProductCatalog::NormalizeTextService.call(product_brand_name)
    )
    product = create(
      :product,
      product_brand: product_brand,
      name: product_name,
      normalized_name: ProductCatalog::NormalizeTextService.call(product_name)
    )

    create(
      :product_variant,
      product: product,
      name: variant_name,
      normalized_name: ProductCatalog::NormalizeTextService.call(variant_name)
    )
  end

  it "returns no results for a blank query" do
    create_catalogue_variant(product_brand_name: "Bio Village", product_name: "Compotes pomme", variant_name: "12 x 90g")

    expect(described_class.call(query: " ")).to be_empty
  end

  it "finds variants through accent-insensitive product brand and product names" do
    variant = create_catalogue_variant(
      product_brand_name: "Bio Village",
      product_name: "Compotes pomme",
      variant_name: "12 x 90g"
    )

    results = described_class.call(query: "ÉPICERIE compote bio village")

    expect(results.map(&:record)).to include(variant.product.product_brand, variant.product, variant)
    expect(results.map(&:record_type)).to include(:product_brand, :product, :product_variant)
  end

  it "finds variants through their own normalized names" do
    variant = create_catalogue_variant(
      product_brand_name: "Maison Dupont",
      product_name: "Jambon blanc",
      variant_name: "4 tranches"
    )

    expect(result_records_for("TRANCHÉS")).to include(variant)
  end

  it "finds variants with misspelled receipt text" do
    variant = create_catalogue_variant(
      product_brand_name: "Bio Village",
      product_name: "Compotes pomme",
      variant_name: "12 x 90g"
    )

    expect(result_records_for("bio vilage compottes pommme")).to include(variant)
  end

  it "finds variants from abbreviated receipt text" do
    variant = create_catalogue_variant(
      product_brand_name: "Maison Dupont",
      product_name: "Jambon blanc",
      variant_name: "4 tranches"
    )

    expect(result_records_for("jambn blnc 4 trnch")).to include(variant)
  end

  it "does not return unrelated catalogue records" do
    create_catalogue_variant(product_brand_name: "Bio Village", product_name: "Compotes pomme", variant_name: "12 x 90g")
    unrelated_variant = create_catalogue_variant(
      product_brand_name: "Maison Dupont",
      product_name: "Jambon blanc",
      variant_name: "4 tranches"
    )

    expect(result_records_for("compote bio")).not_to include(unrelated_variant)
  end

  it "respects the result limit" do
    create_catalogue_variant(product_brand_name: "Bio Village", product_name: "Compotes pomme", variant_name: "12 x 90g")

    expect(described_class.call(query: "bio compotes", limit: 2).size).to eq(2)
  end
end
