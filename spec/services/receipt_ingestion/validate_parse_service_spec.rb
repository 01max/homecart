require "rails_helper"

RSpec.describe ReceiptIngestion::ValidateParseService do
  def build_receipt(total_cents: 500, declared_article_count: 2, parser_warnings: [])
    create(:receipt,
      total_cents: total_cents,
      declared_article_count: declared_article_count,
      parser_status: "needs_review",
      parser_warnings: parser_warnings
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
    build_receipt.tap do |receipt|
      add_line(receipt, position: 1, total_cents: 200)
      add_line(receipt, position: 2, total_cents: 300)
      add_payment(receipt, amount_cents: 500)
    end
  end

  def validate(receipt)
    described_class.call(receipt: receipt)
    receipt.reload
  end

  def warning_codes(receipt)
    receipt.parser_warnings.pluck("code")
  end

  def parser_notice_warning
    {
      code: "parser_notice",
      validator: nil,
      detail: "Parser noticed something",
      value: nil
    }
  end

  def stale_totals_warning
    {
      code: "totals_sum_mismatch",
      validator: "validate_totals_sum",
      detail: "Old mismatch",
      value: 999
    }
  end

  it "marks the receipt parsed when persisted lines, article count, and payments pass" do
    receipt = validate(valid_receipt)

    expect(receipt).to be_parsed
    expect(receipt.parser_warnings).to be_empty
  end

  it "marks the receipt needs_review and records validator warnings when persisted values fail" do
    receipt = build_receipt
    add_line(receipt, position: 1, total_cents: 490, quantity: 1)
    add_payment(receipt, amount_cents: 400)

    receipt = validate(receipt)

    expect(receipt).to be_needs_review
    expect(warning_codes(receipt)).to contain_exactly("totals_sum_mismatch", "article_count_mismatch", "payments_sum_mismatch")
  end

  it "skips the article-count validator when declared article count is nil" do
    receipt = build_receipt(declared_article_count: nil)
    add_line(receipt, position: 1, total_cents: 500, quantity: BigDecimal("2.056"), unit_of_measure: "kg")
    add_payment(receipt, amount_cents: 500)

    receipt = validate(receipt)

    expect(receipt).to be_parsed
    expect(warning_codes(receipt)).not_to include("article_count_mismatch")
  end

  it "keeps non-validator parser warnings as review blockers" do
    receipt = validate(build_receipt(parser_warnings: [ parser_notice_warning ]).tap do |record|
      add_line(record, position: 1, total_cents: 200)
      add_line(record, position: 2, total_cents: 300)
      add_payment(record, amount_cents: 500)
    end)

    expect(receipt).to be_needs_review
    expect(warning_codes(receipt)).to contain_exactly("parser_notice")
  end

  it "replaces stale validator warnings with the current validator result" do
    receipt = validate(build_receipt(parser_warnings: [ stale_totals_warning ]).tap do |record|
      add_line(record, position: 1, total_cents: 200)
      add_line(record, position: 2, total_cents: 300)
      add_payment(record, amount_cents: 500)
    end)

    expect(receipt).to be_parsed
    expect(receipt.parser_warnings).to be_empty
  end
end
