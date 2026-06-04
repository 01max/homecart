require "rails_helper"

RSpec.describe Receipt do
  it "links store, source document, and text extraction evidence" do
    receipt = create(:receipt)

    expect(receipt.store.receipts).to include(receipt)
    expect(receipt.source_document.receipts).to contain_exactly(receipt)
    expect(receipt.text_extraction.receipt).to eq(receipt)
  end

  it "owns receipt details" do
    receipt = create(:receipt)
    line = create(:receipt_line, receipt: receipt)
    promotion = create(:receipt_promotion, receipt: receipt)
    payment = create(:receipt_payment, receipt: receipt)

    expect(receipt.receipt_lines).to contain_exactly(line)
    expect(receipt.receipt_promotions).to contain_exactly(promotion)
    expect(receipt.receipt_payments).to contain_exactly(payment)
  end

  it "declares parser formats and statuses" do
    expect(described_class.parser_formats.keys).to include("leclerc_paper_v1", "leclerc_web_v1")
    expect(described_class.parser_statuses.keys).to contain_exactly("parsed", "needs_review", "reviewed")
  end

  it "sorts recent receipts first" do
    old_receipt = create(:receipt, purchased_at: 2.days.ago)
    new_receipt = create(:receipt, purchased_at: 1.day.ago)

    expect(described_class.recent_first).to start_with(new_receipt, old_receipt)
  end

  it "requires parser warnings to be an array" do
    receipt = create(:receipt).tap { |record| record.parser_warnings = {} }

    expect(receipt).not_to be_valid
  end

  it "validates numeric fields" do
    receipt = create(:receipt).tap { |record| record.declared_article_count = -1 }

    expect(receipt).not_to be_valid
  end
end
