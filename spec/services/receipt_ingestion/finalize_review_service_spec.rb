require "rails_helper"

RSpec.describe ReceiptIngestion::FinalizeReviewService do
  def build_reviewable_receipt(declared_article_count: 2)
    create(:receipt,
      total_cents: 500,
      declared_article_count: declared_article_count,
      parser_status: "needs_review"
    )
  end

  def add_line(receipt, position:, total_cents:, quantity: 1, unit_of_measure: "piece", kind: "item")
    create(:receipt_line,
      receipt: receipt,
      position: position,
      total_cents: total_cents,
      quantity: quantity,
      unit_of_measure: unit_of_measure,
      kind: kind
    )
  end

  def add_payment(receipt, amount_cents:)
    create(:receipt_payment, receipt: receipt, amount_cents: amount_cents)
  end

  def valid_receipt
    build_reviewable_receipt.tap do |receipt|
      first_line = add_line(receipt, position: 1, total_cents: 200)
      add_line(receipt, position: 2, total_cents: 300)
      add_payment(receipt, amount_cents: 500)
      create(:receipt_promotion, receipt: receipt, linked_line: first_line, linking_method: "parser_inferred")
      create(:receipt_promotion, receipt: receipt)
    end
  end

  it "marks a receipt reviewed when every persisted validator passes" do
    result = described_class.call(receipt: valid_receipt)

    expect(result).to be_success
    expect(result.receipt.reload).to be_reviewed
  end

  it "confirms promotion link provenance when review succeeds" do
    receipt = valid_receipt

    described_class.call(receipt: receipt)

    expect(receipt.receipt_promotions.reload.map(&:linking_method)).to contain_exactly("user_confirmed", "unallocated")
  end

  it "keeps a receipt in review when a validator fails" do
    receipt = build_reviewable_receipt
    add_line(receipt, position: 1, total_cents: 500)
    add_payment(receipt, amount_cents: 500)

    result = described_class.call(receipt: receipt)

    expect(result).not_to be_success
    expect(result.failed_validators).to contain_exactly("validate_article_count")
    expect(receipt.reload).to be_needs_review
  end
end
