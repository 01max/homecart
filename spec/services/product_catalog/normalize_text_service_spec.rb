require "rails_helper"

RSpec.describe ProductCatalog::NormalizeTextService do
  it "downcases and removes accents" do
    normalized_text = described_class.call("Épicerie Sucrée")

    expect(normalized_text).to eq("epicerie sucree")
  end

  it "collapses punctuation and whitespace to single spaces" do
    normalized_text = described_class.call("  Bio--Village / Compotes\tPomme  ")

    expect(normalized_text).to eq("bio village compotes pomme")
  end

  it "preserves digits and ASCII letters for package labels" do
    normalized_text = described_class.call("12 x 90g")

    expect(normalized_text).to eq("12 x 90g")
  end

  it "returns an empty string for nil text" do
    normalized_text = described_class.call(nil)

    expect(normalized_text).to eq("")
  end
end
