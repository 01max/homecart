require "rails_helper"

RSpec.describe ReceiptLineMatching::IgnoreLineService do
  subject(:match) { described_class.call(receipt_line: receipt_line) }

  let(:receipt_line) { create(:receipt_line, label: "Ignore this line") }

  it "records an ignored terminal decision without a product variant" do
    expect(match).to have_attributes(
      receipt_line: receipt_line,
      product_variant: nil,
      status: "ignored",
      source: "user",
      label_snapshot: receipt_line.label
    )
    expect(ReceiptLineMatching::QueueService.call.flat_map(&:receipt_lines)).not_to include(receipt_line)
  end

  it "removes a previous confirmed price observation when a line is ignored" do
    variant = create(:product_variant)
    confirmed = ReceiptLineMatching::ConfirmMatchService.call(receipt_line: receipt_line, product_variant: variant)

    expect(match.id).to eq(confirmed.receipt_line_match.id)
    expect(match.reload).to have_attributes(status: "ignored", product_variant: nil)
    expect(PriceObservation.exists?(receipt_line: receipt_line)).to be(false)
  end
end
