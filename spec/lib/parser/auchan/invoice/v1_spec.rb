require "rails_helper"

RSpec.describe Parser::Auchan::Invoice::V1 do
  describe "registry" do
    it "registers the parser under the Auchan invoice v1 format" do
      expect(Parser::Registry.for(parser_format)).to eq(described_class)
      expect(Parser::Registry.for("auchan.paper.v1")).to eq(Parser::Auchan::Paper::V1)
    end
  end

  describe "#call" do
    it "parses invoice header fields without till identity" do
      result = parse_fixture

      expect_invoice_header(result)
      expect(result.warnings).to be_empty
    end

    it "parses invoice item rows with source references and VAT rates" do
      result = parse_fixture

      expect(item_lines(result)).to include(
        cappuccino_line,
        peanut_line,
        cotton_line
      )
    end

    it "derives unit prices only when item totals divide evenly into cents" do
      result = parse_fixture

      expect(line_named(result, "MENGUY S PEANUT CHOCO 430G")).to include(unit_price_cents: 429)
      expect(line_named(result, "YOPLAIT PAW PATROL PANACHE X12")).to include(unit_price_cents: nil)
    end

    it "keeps raw invoice rows as receipt-line evidence" do
      result = parse_fixture

      expect(line_named(result, "AUC CAFE SOLUBLE CAPPUCCINO")).to include(raw_text: cappuccino_raw_text)
    end

    it "parses eco-participation rows as separate fee lines" do
      result = parse_fixture

      expect(fee_lines(result)).to match_array(eco_participation_fee_lines)
    end

    it "captures line-level WAAOH credits and WAAOH cash spend" do
      result = parse_fixture

      expect(result.promotions).to match_array(invoice_promotions)
    end

    it "parses coupon, WAAOH, and bank-card payment rows" do
      result = parse_fixture

      expect(result.payments).to match_array(invoice_payments)
    end

    it "reconciles invoice lines and payments against the paid total" do
      result = parse_fixture

      expect_invoice_reconciliation(result)
    end

    it "routes invoice line total mismatches to needs_review" do
      result = parse_text(fixture_text.sub("0,15        3,09", "0,15        3,19"))

      expect(result.receipt).to include(parser_status: "needs_review")
      expect(result.warnings).to contain_exactly(
        a_hash_including(code: "totals_sum_mismatch", validator: "validate_totals_sum", value: 10)
      )
    end

    it "routes invoice payment total mismatches to needs_review" do
      result = parse_text(fixture_text.sub("CARTE BANCAIRE                           4,65", "CARTE BANCAIRE                           4,60"))

      expect(result.receipt).to include(parser_status: "needs_review")
      expect(result.warnings).to contain_exactly(
        a_hash_including(code: "payments_sum_mismatch", validator: "validate_payments_sum", value: -5)
      )
    end

    it "skips malformed product totals and routes the discrepancy to review" do
      result = parse_text(fixture_text.sub("0,15        3,09", "0,15        BROKEN"))

      expect(result.receipt).to include(parser_status: "needs_review")
      expect(line_named(result, "AUC CAFE SOLUBLE CAPPUCCINO")).to be_nil
      expect(result.warnings).to contain_exactly(
        a_hash_including(code: "totals_sum_mismatch", validator: "validate_totals_sum", value: -309)
      )
    end
  end

  def parser_format
    "auchan.invoice.v1"
  end

  def parse_fixture
    parse_text(fixture_text)
  end

  def parse_text(text)
    described_class.new(text: text).call
  end

  def fixture_text
    Rails.root.join("spec/fixtures/files/parser/auchan_invoice_v1.txt").read
  end

  def item_lines(result)
    result.lines.select { |line| line.fetch(:kind) == "item" }
  end

  def fee_lines(result)
    result.lines.select { |line| line.fetch(:kind) == "fee" }
  end

  def line_named(result, label)
    item_lines(result).find { |line| line.fetch(:label) == label }
  end

  def expect_invoice_header(result)
    expect(result.receipt).to include(
      parser_format: parser_format,
      purchased_at: Time.zone.local(2026, 3, 28),
      register_number: nil,
      ticket_number: nil,
      cashier_code: nil,
      total_cents: 3_642,
      parser_status: "parsed"
    )
  end

  def cappuccino_raw_text
    a_string_including(
      "3245678041727",
      "AUC CAFE SOLUBLE CAPPUCCINO",
      "3,09"
    )
  end

  def eco_participation_fee_lines
    [
      joker_eco_participation_fee,
      apple_juice_eco_participation_fee,
      yoplait_eco_participation_fee
    ]
  end

  def invoice_promotions
    [
      cappuccino_waaoh_credit,
      apple_juice_waaoh_credit,
      waaoh_debit_promotion
    ]
  end

  def invoice_payments
    [
      auchan_reduction_payment,
      euro_reduction_payment,
      bank_card_payment(amount_cents: 2_500),
      waaoh_payment,
      bank_card_payment(amount_cents: 465)
    ]
  end

  def expect_invoice_reconciliation(result)
    aggregate_failures do
      expect(result.receipt).to include(total_cents: 3_642, parser_status: "parsed")
      expect(result.lines.sum { |line| line.fetch(:total_cents) }).to eq(3_642)
      expect(result.payments.sum { |payment| payment.fetch(:amount_cents) }).to eq(3_642)
      expect(fee_lines(result).sum { |line| line.fetch(:total_cents) }).to eq(14)
      expect(result.warnings).to be_empty
    end
  end

  def cappuccino_line
    hash_including(
      position: 1,
      source_reference: "3245678041727",
      label: "AUC CAFE SOLUBLE CAPPUCCINO",
      quantity: BigDecimal("1"),
      unit_price_cents: 309,
      total_cents: 309,
      vat_rate_bp: 550,
      kind: "item"
    )
  end

  def peanut_line
    hash_including(
      position: 6,
      source_reference: "3327272108096",
      label: "MENGUY S PEANUT CHOCO 430G",
      quantity: BigDecimal("2"),
      unit_price_cents: 429,
      total_cents: 858,
      vat_rate_bp: 550,
      kind: "item"
    )
  end

  def cotton_line
    hash_including(
      position: 7,
      source_reference: "3596710560097",
      label: "AUCHAN COTON DOUX X180",
      quantity: BigDecimal("3"),
      unit_price_cents: 364,
      total_cents: 1_092,
      vat_rate_bp: 2_000,
      kind: "item"
    )
  end

  def joker_eco_participation_fee
    eco_participation_fee(position: 3, amount_cents: 3)
  end

  def apple_juice_eco_participation_fee
    eco_participation_fee(position: 5, amount_cents: 4)
  end

  def yoplait_eco_participation_fee
    eco_participation_fee(position: 9, amount_cents: 7)
  end

  def eco_participation_fee(position:, amount_cents:)
    hash_including(
      position: position,
      source_reference: nil,
      raw_text: a_string_including("Eco-participation", cents_text(amount_cents)),
      label: "Eco-participation",
      quantity: BigDecimal("1"),
      total_cents: amount_cents,
      kind: "fee"
    )
  end

  def cappuccino_waaoh_credit
    waaoh_credit(label: "AUC CAFE SOLUBLE CAPPUCCINO", delta: 15, linked_line_position: 1)
  end

  def apple_juice_waaoh_credit
    waaoh_credit(label: "AUCHAN PUR JUS POMME PET 2L", delta: 11, linked_line_position: 4)
  end

  def waaoh_credit(label:, delta:, linked_line_position:)
    {
      program: "auchan_waaoh",
      unit: "euro_cents",
      delta: delta,
      label: label,
      kind: "loyalty_cash_credit",
      linked_line_position: linked_line_position,
      linking_method: "parser_inferred"
    }
  end

  def waaoh_debit_promotion
    {
      program: "auchan_waaoh",
      unit: "euro_cents",
      delta: -147,
      label: "WAAOH",
      kind: "loyalty_cash_debit",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def auchan_reduction_payment
    invoice_payment(raw_label: "BON DE REDUCTION AUCHAN", category: "other", amount_cents: 500)
  end

  def euro_reduction_payment
    invoice_payment(raw_label: "BON REDUCTION EURO", category: "other", amount_cents: 30)
  end

  def bank_card_payment(amount_cents:)
    invoice_payment(raw_label: "CARTE BANCAIRE", category: "bank_card", amount_cents: amount_cents)
  end

  def waaoh_payment
    invoice_payment(raw_label: "WAAOH", category: "other", amount_cents: 147)
  end

  def invoice_payment(raw_label:, category:, amount_cents:)
    hash_including(raw_label: raw_label, category: category, amount_cents: amount_cents)
  end

  def cents_text(amount_cents)
    format("%<euros>d,%<cents>02d", euros: amount_cents / 100, cents: amount_cents % 100)
  end
end
