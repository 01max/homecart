require "rails_helper"

RSpec.describe ReceiptLineMatching::BulkConfirmService do
  let(:variant) { create(:product_variant) }

  it "previews and confirms eligible lines for one normalized label" do
    first_line, second_line = create_lait_lines

    preview = described_class.preview(normalized_label: "lait demi ecreme")
    result = call_service(expected_receipt_line_ids: preview.receipt_line_ids)

    expect(preview.receipt_lines).to contain_exactly(first_line, second_line)
    expect(result.confirmations.map(&:receipt_line_match).map(&:receipt_line)).to contain_exactly(first_line, second_line)
    expect(ReceiptLineMatch.confirmed.where(product_variant: variant).count).to eq(2)
  end

  it "rejects stale bulk confirmations when the affected count changed" do
    create(:receipt_line, receipt: create(:receipt, :reviewed), label: "Lait demi ecreme")

    expect { call_service(expected_receipt_line_ids: [ SecureRandom.uuid ]) }.to raise_error(ArgumentError)
  end

  it "rejects stale bulk confirmations when the affected set changed but the count did not" do
    first_line, second_line = create_lait_lines
    preview = described_class.preview(normalized_label: "lait demi ecreme")
    create(:receipt_line_match, :ignored, receipt_line: first_line)
    create(:receipt_line, receipt: create(:receipt, :reviewed), label: second_line.label)

    expect { call_service(expected_receipt_line_ids: preview.receipt_line_ids) }.to raise_error(ArgumentError)
  end

  def call_service(expected_receipt_line_ids:)
    described_class.call(
      normalized_label: "lait demi ecreme",
      product_variant: variant,
      expected_receipt_line_ids: expected_receipt_line_ids
    )
  end

  def create_lait_lines
    [
      create(:receipt_line, receipt: create(:receipt, :reviewed), label: "Lait demi ecreme"),
      create(:receipt_line, receipt: create(:receipt, :reviewed), label: "LAIT demi écrémé")
    ].tap do
      ignored_line = create(:receipt_line, receipt: create(:receipt, :reviewed), label: "Lait demi ecreme")
      create(:receipt_line_match, :ignored, receipt_line: ignored_line)
    end
  end
end
