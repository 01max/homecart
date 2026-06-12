require "rails_helper"

RSpec.describe ReceiptLineMatching::RejectMatchService do
  let(:variant) { create(:product_variant) }
  let(:receipt_line) { create(:receipt_line, label: "compote bio village") }
  let!(:suggestion) { create(:receipt_line_match, :suggested, receipt_line: receipt_line, product_variant: variant) }

  it "records a rejected suggestion and suppresses it for that line" do
    rejection = described_class.call(receipt_line: receipt_line, product_variant: variant)

    expect(rejection).to have_attributes(status: "rejected", product_variant: variant, source: "user")
    expect(rejection.id).to eq(suggestion.id)
    expect(ReceiptLineMatching::SuggestMatchesService.call(receipt_line: receipt_line).map(&:product_variant))
      .not_to include(variant)
  end

  it "does not create a price observation" do
    expect do
      described_class.call(receipt_line: receipt_line, product_variant: variant)
    end.not_to change(PriceObservation, :count)
  end
end
