require "rails_helper"

RSpec.describe Product do
  it "belongs to a product brand and category" do
    product_brand = create(:product_brand)
    category = create(:category)
    product = create(:product, product_brand: product_brand, category: category)

    expect(product.product_brand).to eq(product_brand)
    expect(product.category).to eq(category)
  end

  it "can belong to a manufacturer" do
    manufacturer = create(:manufacturer)
    product = create(:product, manufacturer: manufacturer)

    expect(product.manufacturer).to eq(manufacturer)
  end

  it "allows a missing manufacturer" do
    product = build(:product, manufacturer: nil)

    expect(product).to be_valid
  end

  it "requires a category" do
    product = build(:product, category: nil)

    expect(product).not_to be_valid
  end

  it "owns product variants" do
    product = create(:product)
    variant = create(:product_variant, product: product)

    expect(product.product_variants).to contain_exactly(variant)
  end

  it "requires normalized names to be unique within a brand and category" do
    product = create(:product, normalized_name: "compotes-pomme")
    duplicate = build(
      :product,
      product_brand: product.product_brand,
      category: product.category,
      normalized_name: "compotes-pomme"
    )

    expect(duplicate).not_to be_valid
  end

  it "allows the same normalized name in another category" do
    product = create(:product, normalized_name: "compotes-pomme")
    duplicate = build(
      :product,
      product_brand: product.product_brand,
      category: create(:category),
      normalized_name: "compotes-pomme"
    )

    expect(duplicate).to be_valid
  end

  it "requires slugs to be unique within a brand and category" do
    product = create(:product, slug: "compotes-pomme")
    duplicate = build(
      :product,
      product_brand: product.product_brand,
      category: product.category,
      slug: "compotes-pomme"
    )

    expect(duplicate).not_to be_valid
  end
end
