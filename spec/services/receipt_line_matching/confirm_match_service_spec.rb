require "rails_helper"

RSpec.describe ReceiptLineMatching::ConfirmMatchService do
  subject(:result) { described_class.call(receipt_line: receipt_line, product_variant: variant) }

  let(:variant) { create(:product_variant) }
  let(:receipt_line) { create(:receipt_line, quantity: 2, total_cents: 500, unit_of_measure: "piece") }

  it "records a confirmed match and persists the price observation" do
    expect(result.receipt_line_match).to have_attributes(
      receipt_line: receipt_line,
      product_variant: variant,
      status: "confirmed",
      source: "user",
      label_snapshot: receipt_line.label
    )
    expect(result.price_observation).to have_attributes(receipt_line: receipt_line, pack_unit_price_cents: 250)
  end

  it "creates one price observation for the confirmed match" do
    expect { result }.to change(PriceObservation, :count).by(1)
  end

  it "replaces a prior terminal decision safely" do
    first_result = result
    second_variant = create(:product_variant)

    second_result = described_class.call(receipt_line: receipt_line, product_variant: second_variant)

    expect(second_result.receipt_line_match).to eq(first_result.receipt_line_match)
    expect(receipt_line.receipt_line_matches.terminal_decisions.count).to eq(1)
    expect(second_result.receipt_line_match.reload.product_variant).to eq(second_variant)
    expect(second_result.price_observation.reload.product_variant).to eq(second_variant)
  end

  it "updates the existing price observation when the confirmed variant changes" do
    first_observation = result.price_observation
    second_variant = create(:product_variant)

    second_result = described_class.call(receipt_line: receipt_line, product_variant: second_variant)

    expect(second_result.price_observation).to eq(first_observation)
    expect(PriceObservation.where(receipt_line: receipt_line).count).to eq(1)
    expect(first_observation.reload.product_variant).to eq(second_variant)
  end
end
