require "rails_helper"

RSpec.describe Store do
  it "belongs to a retail brand" do
    brand = create(:retail_brand)
    store = create(:store, retail_brand: brand)

    expect(store.retail_brand).to eq(brand)
  end

  it "owns source documents and receipts" do
    store = create(:store)
    source_document = create(:source_document, store: store)
    receipt = create(:receipt, store: store, source_document: source_document)

    expect(store.source_documents).to include(source_document)
    expect(store.receipts).to include(receipt)
  end

  it "declares the supported channels" do
    expect(described_class.channels.keys).to contain_exactly("physical", "drive", "click_collect")
  end

  it "requires identifiers to be an object" do
    store = described_class.new(retail_brand: create(:retail_brand), location_name: "Location", channel: "physical", identifiers: [])

    expect(store).not_to be_valid
  end

  it "requires location names to be unique per brand and channel" do
    store = create(:store, location_name: "Location", channel: "physical")
    duplicate = described_class.new(retail_brand: store.retail_brand, location_name: "Location", channel: "physical")

    expect(duplicate).not_to be_valid
  end

  it "allows the same location name on another channel" do
    store = create(:store, location_name: "Location", channel: "physical")
    other_channel = described_class.new(retail_brand: store.retail_brand, location_name: "Location", channel: "drive")

    expect(other_channel).to be_valid
  end
end
