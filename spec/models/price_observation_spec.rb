require "rails_helper"

RSpec.describe PriceObservation do
  it "belongs to its source match, receipt line, variant, and store" do
    observation = create(:price_observation)

    expect(observation.receipt_line_match).to be_present
    expect(observation.receipt_line).to eq(observation.receipt_line_match.receipt_line)
    expect(observation.product_variant).to eq(observation.receipt_line_match.product_variant)
    expect(observation.store).to eq(observation.receipt_line.receipt.store)
  end

  it "declares purchased unit and source enums" do
    observation = build(:price_observation, purchased_unit: "kg")

    expect(described_class.purchased_units.keys).to contain_exactly("piece", "kg", "g", "l", "ml")
    expect(described_class.sources.keys).to contain_exactly("receipt_line")
    expect(observation.kg?).to be(true)
    expect(observation.source_receipt_line?).to be(true)
  end

  it "validates observed quantities and prices" do
    observation = build(
      :price_observation,
      purchased_quantity: 0,
      total_cents: -1,
      pack_unit_price_cents: -1,
      comparison_unit_price_cents: -1
    )

    expect(observation).not_to be_valid
  end

  it "requires comparison unit and comparison price to be present together" do
    without_price = build(:price_observation, comparison_unit: create(:comparison_unit))
    without_unit = build(:price_observation, comparison_unit_price_cents: 123)
    complete = build(:price_observation, :with_comparison_unit_price)

    expect(without_price).not_to be_valid
    expect(without_unit).not_to be_valid
    expect(complete).to be_valid
  end

  it "requires one observation per receipt-line match" do
    observation = create(:price_observation)
    duplicate = build(:price_observation, receipt_line_match: observation.receipt_line_match)

    expect(duplicate).not_to be_valid
  end

  it "requires one observation per receipt line" do
    observation = create(:price_observation)
    duplicate_match = create(:receipt_line_match, receipt_line: create(:receipt_line))
    duplicate = build(
      :price_observation,
      receipt_line_match: duplicate_match,
      receipt_line: observation.receipt_line
    )

    expect(duplicate).not_to be_valid
  end

  context "with price history for multiple variants and stores" do
    let(:history) do
      variant = create(:product_variant)
      store = create(:store)
      old_line = create(:receipt_line, receipt: create(:receipt, store: store, purchased_at: 2.days.ago))
      new_line = create(:receipt_line, receipt: create(:receipt, store: store, purchased_at: 1.day.ago))
      old_observation = create_history_observation(variant, store, old_line, 2.days.ago)
      new_observation = create_history_observation(variant, store, new_line, 1.day.ago)

      { variant: variant, store: store, observations: [ new_observation, old_observation ] }
    end

    before do
      other_line = create(:receipt_line, receipt: create(:receipt, purchased_at: 3.days.ago))
      other_match = create(:receipt_line_match, receipt_line: other_line)
      create(:price_observation, receipt_line_match: other_match, receipt_line: other_line, observed_at: 3.days.ago)
    end

    it "scopes variant and store price history in reverse chronological order" do
      expect(described_class.variant_store_history(history.fetch(:variant), history.fetch(:store)))
        .to eq(history.fetch(:observations))
    end

    it "filters variant and store price history by observed date" do
      new_observation = history.fetch(:observations).first

      expect(described_class.variant_store_history(history.fetch(:variant), history.fetch(:store)).observed_on(new_observation.observed_at.to_date))
        .to eq([ new_observation ])
    end

    def create_history_observation(variant, store, line, observed_at)
      match = create(:receipt_line_match, receipt_line: line, product_variant: variant)
      create(:price_observation, receipt_line_match: match, receipt_line: line, product_variant: variant, store: store, observed_at: observed_at)
    end
  end
end
