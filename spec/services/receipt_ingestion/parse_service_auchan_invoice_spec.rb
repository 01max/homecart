require "rails_helper"

RSpec.describe ReceiptIngestion::ParseService do
  it "persists the Auchan invoice parser graph with source references and loyalty rows" do
    source_document = create(:source_document, parser_format: "auchan.invoice.v1")
    text_extraction = create(:text_extraction, source_document: source_document, text: fixture_text)

    result = described_class.call(text_extraction: text_extraction)

    expect_persisted_invoice_receipt(result.receipt, source_document, text_extraction)
    expect_persisted_invoice_lines(result.receipt)
    expect_persisted_invoice_promotions(result.receipt)
    expect_persisted_invoice_payments(result.receipt)
  end

  def expect_persisted_invoice_receipt(receipt, source_document, text_extraction)
    expect(receipt).to have_attributes(
      store: source_document.store,
      source_document: source_document,
      text_extraction: text_extraction,
      purchased_at: Time.zone.local(2026, 3, 28),
      register_number: nil,
      ticket_number: nil,
      cashier_code: nil,
      total_cents: 3_642,
      declared_article_count: nil,
      parser_warnings: []
    )
    expect(receipt).to be_parser_format_auchan_invoice_v1
    expect(receipt).to be_parsed
  end

  def expect_persisted_invoice_lines(receipt)
    lines = receipt.receipt_lines.order(:position).to_a

    aggregate_failures do
      expect(lines.size).to eq(12)
      expect(lines.sum(&:total_cents)).to eq(3_642)
      expect(lines.find { |line| line.label == "AUC CAFE SOLUBLE CAPPUCCINO" }).to have_attributes(
        position: 1,
        source_reference: "3245678041727",
        quantity: BigDecimal("1"),
        unit_price_cents: 309,
        total_cents: 309,
        vat_rate_bp: 550,
        kind: "item"
      )
      expect(lines.find { |line| line.label == "YOPLAIT PAW PATROL PANACHE X12" }).to have_attributes(
        unit_price_cents: nil,
        total_cents: 325
      )
      expect(lines.select(&:kind_fee?).map(&:total_cents)).to contain_exactly(3, 4, 7)
    end
  end

  def expect_persisted_invoice_promotions(receipt)
    cappuccino = receipt.receipt_lines.find_by!(label: "AUC CAFE SOLUBLE CAPPUCCINO")
    apple_juice = receipt.receipt_lines.find_by!(label: "AUCHAN PUR JUS POMME PET 2L")

    expect(receipt.receipt_promotions).to contain_exactly(
      have_attributes(
        program: "auchan_waaoh",
        unit: "euro_cents",
        delta: 15,
        label: "AUC CAFE SOLUBLE CAPPUCCINO",
        kind: "loyalty_cash_credit",
        linked_line: cappuccino,
        linking_method: "parser_inferred"
      ),
      have_attributes(
        program: "auchan_waaoh",
        unit: "euro_cents",
        delta: 11,
        label: "AUCHAN PUR JUS POMME PET 2L",
        kind: "loyalty_cash_credit",
        linked_line: apple_juice,
        linking_method: "parser_inferred"
      ),
      have_attributes(
        program: "auchan_waaoh",
        unit: "euro_cents",
        delta: -147,
        label: "WAAOH",
        kind: "loyalty_cash_debit",
        linked_line: nil,
        linking_method: "unallocated"
      )
    )
  end

  def expect_persisted_invoice_payments(receipt)
    expect(receipt.receipt_payments.order(:position).map { |payment| payment.attributes.symbolize_keys }).to match(
      [
        a_hash_including(raw_label: "BON DE REDUCTION AUCHAN", category: "other", amount_cents: 500),
        a_hash_including(raw_label: "BON REDUCTION EURO", category: "other", amount_cents: 30),
        a_hash_including(raw_label: "CARTE BANCAIRE", category: "bank_card", amount_cents: 2_500),
        a_hash_including(raw_label: "WAAOH", category: "other", amount_cents: 147),
        a_hash_including(raw_label: "CARTE BANCAIRE", category: "bank_card", amount_cents: 465)
      ]
    )
  end

  def fixture_text
    Rails.root.join("spec/fixtures/files/parser/auchan_invoice_v1.txt").read
  end
end
