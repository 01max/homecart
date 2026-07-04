require "rails_helper"

RSpec.describe "Parser::Auchan::Invoice::V1" do
  describe "registry" do
    it "registers the parser under the Auchan invoice v1 format" do
      pending(pending_implementation)

      expect(Parser::Registry.for(parser_format)).to eq(parser_class)
      expect(Parser::Registry.for("auchan.paper.v1")).to eq(Parser::Auchan::Paper::V1)
    end
  end

  describe "#call" do
    it "parses invoice header fields without till identity" do
      pending(pending_implementation)

      result = parse_fixture

      expect_invoice_header(result)
      expect(result.warnings).to be_empty
    end

    it "parses invoice item rows with source references and VAT rates" do
      pending(pending_implementation)

      result = parse_fixture

      expect(item_lines(result)).to include(
        cappuccino_line,
        peanut_line,
        cotton_line
      )
    end

    it "derives unit prices only when item totals divide evenly into cents" do
      pending(pending_implementation)

      result = parse_fixture

      expect(line_named(result, "MENGUY S PEANUT CHOCO 430G")).to include(unit_price_cents: 429)
      expect(line_named(result, "YOPLAIT PAW PATROL PANACHE X12")).to include(unit_price_cents: nil)
    end

    it "keeps raw invoice rows as receipt-line evidence" do
      pending(pending_implementation)

      result = parse_fixture

      expect(line_named(result, "AUC CAFE SOLUBLE CAPPUCCINO")).to include(raw_text: cappuccino_raw_text)
    end
  end

  def pending_implementation
    "Parser::Auchan::Invoice::V1 is implemented in OpenSpec task 3.1"
  end

  def parser_format
    "auchan.invoice.v1"
  end

  def parse_fixture
    parser_class.new(text: fixture_text).call
  end

  def parser_class
    Parser::Auchan::Invoice::V1
  end

  def fixture_text
    Rails.root.join("spec/fixtures/files/parser/auchan_invoice_v1.txt").read
  end

  def item_lines(result)
    result.lines.select { |line| line.fetch(:kind) == "item" }
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
      source_reference: "3596710560097",
      label: "AUCHAN COTON DOUX X180",
      quantity: BigDecimal("3"),
      unit_price_cents: 364,
      total_cents: 1_092,
      vat_rate_bp: 2_000,
      kind: "item"
    )
  end
end
