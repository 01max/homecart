require "rails_helper"

RSpec.describe RetailBrand do
  it "owns stores" do
    brand = create_retail_brand
    store = create_store(retail_brand: brand)

    expect(brand.stores).to contain_exactly(store)
  end

  it "requires a name" do
    brand = described_class.new(slug: "retailer", aliases: [])

    expect(brand).not_to be_valid
  end

  it "requires a unique slug" do
    create_retail_brand(slug: "retailer")
    duplicate = described_class.new(name: "Duplicate", slug: "retailer", aliases: [])

    expect(duplicate).not_to be_valid
  end

  it "requires aliases to be an array" do
    brand = described_class.new(name: "Retailer", slug: "retailer", aliases: {})

    expect(brand).not_to be_valid
  end
end
