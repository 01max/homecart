require "rails_helper"

RSpec.describe ReceiptLineMatching::ReceiptQueueService do
  subject(:entries) { described_class.call(receipt: receipt) }

  let(:receipt) { create(:receipt, :reviewed) }
  let(:variant) do
    create_catalogue_variant(
      product_brand_name: "Bio Village",
      product_name: "Lait demi ecreme",
      variant_name: "6 x 1L"
    )
  end
  let!(:target_line) { create(:receipt_line, receipt: receipt, position: 1, label: "LAIT DEMI ECREME") }

  before do
    prior_line = create(:receipt_line, receipt: create(:receipt, :reviewed), label: "Lait demi ecreme")
    ReceiptLineMatching::ConfirmMatchService.call(receipt_line: prior_line, product_variant: variant)
    create(:receipt_line, receipt: receipt, position: 2, kind: "fee", label: "Service fee")
    ignored_line = create(:receipt_line, receipt: receipt, position: 3, label: "Ignore me")
    create(:receipt_line_match, :ignored, receipt_line: ignored_line)
    create(:receipt_line, receipt: create(:receipt, :reviewed), label: "LAIT DEMI ECREME")
  end

  it "returns one receipt's unmatched item lines with suggestions" do
    expect(entries.map(&:receipt_line)).to eq([ target_line ])
    expect(entries.first.suggestions.map(&:product_variant)).to include(variant)
  end

  it "does not auto-confirm receipt-specific suggestions" do
    expect(ReceiptLineMatch.confirmed.exists?(receipt_line: target_line)).to be(false)
  end

  it "returns no entries until the receipt is reviewed" do
    receipt.update!(parser_status: "needs_review")

    expect(entries).to be_empty
  end

  def create_catalogue_variant(product_brand_name:, product_name:, variant_name:)
    product_brand = create(:product_brand, name: product_brand_name)
    product = create(:product, product_brand: product_brand, name: product_name)

    create(:product_variant, product: product, name: variant_name)
  end
end
