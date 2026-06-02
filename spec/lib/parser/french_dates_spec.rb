require "rails_helper"

RSpec.describe Parser::FrenchDates do
  describe ".month_number" do
    it "resolves full French month names and known abbreviations exactly" do
      expect(described_class.month_number("janvier")).to eq(1)
      expect(described_class.month_number("janv.")).to eq(1)
      expect(described_class.month_number("févr")).to eq(2)
      expect(described_class.month_number("déc.")).to eq(12)
    end

    it "does not guess from ambiguous or partial prefixes" do
      expect { described_class.month_number("ju") }.to raise_error(KeyError)
      expect { described_class.month_number("jan") }.to raise_error(KeyError)
    end
  end
end
