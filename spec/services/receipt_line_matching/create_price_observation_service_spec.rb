require "rails_helper"

RSpec.describe ReceiptLineMatching::CreatePriceObservationService do
  subject(:observation) { described_class.call(receipt_line_match: receipt_line_match) }

  let(:receipt_line) { create(:receipt_line, quantity: 2, total_cents: 500, unit_of_measure: "piece") }
  let(:product_variant) { create(:product_variant) }
  let(:receipt_line_match) { create(:receipt_line_match, receipt_line: receipt_line, product_variant: product_variant) }

  it "creates the price observation for a confirmed match" do
    expect(observation).to have_attributes(price_attributes)
  end

  it "computes comparison-unit price when variant quantity fields are present" do
    comparison_unit = create(:comparison_unit, name: "Liter", symbol: "L")
    product_variant.update!(comparison_unit: comparison_unit, package_count: 6, quantity_value: 1)

    expect(observation).to have_attributes(comparison_unit: comparison_unit, comparison_unit_price_cents: 42)
  end

  it "leaves comparison-unit price blank without variant quantity fields" do
    product_variant.update!(comparison_unit: nil, package_count: nil, quantity_value: nil)

    expect(observation).to have_attributes(comparison_unit: nil, comparison_unit_price_cents: nil)
  end

  it "updates the existing observation for the match" do
    existing_observation = create(:price_observation, receipt_line_match: receipt_line_match)

    expect(observation).to eq(existing_observation)
    expect(observation.reload).to have_attributes(price_attributes)
  end

  it "rejects non-confirmed matches" do
    receipt_line_match.update!(status: "rejected")

    expect { observation }.to raise_error(ArgumentError)
  end

  def price_attributes
    {
      receipt_line: receipt_line,
      product_variant: product_variant,
      store: receipt_line.receipt.store,
      total_cents: 500,
      pack_unit_price_cents: 250,
      source: "receipt_line"
    }
  end
end
