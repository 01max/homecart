require "rails_helper"

RSpec.describe ProductBrand do
  it "owns products" do
    product_brand = create(:product_brand)
    product = create(:product, product_brand: product_brand)

    expect(product_brand.products).to contain_exactly(product)
  end

  it "can belong to a retail brand as a private label" do
    retail_brand = create(:retail_brand)
    product_brand = create(:product_brand, :private_label, retail_brand: retail_brand)

    expect(product_brand.retail_brand).to eq(retail_brand)
    expect(retail_brand.product_brands).to contain_exactly(product_brand)
  end

  it "can be a national brand without a retail brand" do
    product_brand = build(:product_brand, retail_brand: nil)

    expect(product_brand).to be_valid
  end

  it "requires a unique normalized name" do
    create(:product_brand, normalized_name: "andros")
    duplicate = build(:product_brand, normalized_name: "andros")

    expect(duplicate).not_to be_valid
  end

  it "requires a unique slug" do
    create(:product_brand, slug: "andros")
    duplicate = build(:product_brand, slug: "andros")

    expect(duplicate).not_to be_valid
  end
end
