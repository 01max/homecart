require "rails_helper"

RSpec.describe Manufacturer do
  it "owns products" do
    manufacturer = create(:manufacturer)
    product = create(:product, manufacturer: manufacturer)

    expect(manufacturer.products).to contain_exactly(product)
  end

  it "requires a name" do
    manufacturer = described_class.new(normalized_name: "manufacturer", slug: "manufacturer")

    expect(manufacturer).not_to be_valid
  end

  it "requires a unique normalized name" do
    create(:manufacturer, normalized_name: "compotes-co")
    duplicate = build(:manufacturer, normalized_name: "compotes-co")

    expect(duplicate).not_to be_valid
  end

  it "requires a unique slug" do
    create(:manufacturer, slug: "compotes-co")
    duplicate = build(:manufacturer, slug: "compotes-co")

    expect(duplicate).not_to be_valid
  end
end
