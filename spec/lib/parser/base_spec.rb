require "rails_helper"

RSpec.describe Parser::Base do
  subject(:parser) { test_parser.new(text: "receipt text") }

  let(:test_parser) do
    Class.new(described_class) do
      public :result_envelope,
             :validate_totals_sum,
             :validate_article_count,
             :validate_payments_sum,
             :add_warning,
             :cents_from,
             :french_month_number,
             :payment_category
    end
  end

  describe "#call" do
    it "requires subclasses to implement receipt attributes" do
      expect { parser.call }.to raise_error(NotImplementedError, /must implement #receipt_attributes/)
    end

    it "builds a result envelope and runs validators through subclass hooks" do
      result = callable_parser.new(text: "receipt text").call

      expect(result.receipt).to include(total_cents: 500, declared_article_count: 2, parser_status: "parsed")
      expect(result.lines).to contain_exactly(hash_including(position: 1, total_cents: 200), hash_including(position: 2, total_cents: 300))
      expect(result.payments).to contain_exactly(hash_including(amount_cents: 500))
      expect(result.warnings).to be_empty
    end

    it "keeps parsed status when the article-count validator is skipped for nil declared count" do
      result = callable_parser(declared_article_count: nil, line_quantities: [ 999 ]).new(text: "receipt text").call

      expect(result.receipt[:parser_status]).to eq("parsed")
      expect(result.warnings).to be_empty
    end

    it "keeps parsed status within the one-cent monetary validator tolerance" do
      result = callable_parser(total_cents: 500, declared_article_count: 1, line_totals: [ 499 ], payment_amounts: [ 501 ]).new(text: "receipt text").call

      expect(result.receipt[:parser_status]).to eq("parsed")
      expect(result.warnings).to be_empty
    end
  end

  describe "#result_envelope" do
    it "builds a parser result with receipt, lines, promotions, payments, and warnings" do
      result = envelope(**result_input_attributes)

      expect(result).to have_attributes(result_output_attributes)
    end

    it "rejects free-form warning strings" do
      expect do
        envelope(warnings: [ "not structured" ])
      end.to raise_error(described_class::WarningShapeError, /warning must be a hash/)
    end
  end

  describe "#add_warning" do
    it "appends structured four-field warning hashes" do
      warning = parser.add_warning(code: "parser_exception", detail: "Parser failed")

      expect(warning).to eq(parser_exception_warning)
      expect(parser.warnings).to contain_exactly(parser_exception_warning)
    end

    it "rejects non-numeric warning values" do
      expect do
        parser.add_warning(code: "bad_value", detail: "Bad value", value: "1")
      end.to raise_error(described_class::WarningShapeError, "warning value must be numeric or nil")
    end
  end

  describe "#validate_totals_sum" do
    it "passes when line totals exactly match the receipt total" do
      result = envelope(receipt: { total_cents: 1_000 }, lines: [ { total_cents: 400 }, { total_cents: 600 } ])

      expect(parser.validate_totals_sum(result)).to be(true)
      expect(parser.warnings).to be_empty
    end

    it "passes within the one-cent monetary tolerance" do
      result = envelope(receipt: { total_cents: 1_000 }, lines: [ { total_cents: 999 } ])

      expect(parser.validate_totals_sum(result)).to be(true)
      expect(parser.warnings).to be_empty
    end

    it "adds a structured warning when line totals differ by more than one cent" do
      result = envelope(receipt: { total_cents: 1_000 }, lines: [ { total_cents: 997 } ])

      expect(parser.validate_totals_sum(result)).to be(false)
      expect(parser.warnings).to contain_exactly(totals_warning)
    end
  end

  describe "#validate_article_count" do
    it "skips the validator when declared article count is nil" do
      result = envelope(receipt: { declared_article_count: nil }, lines: [ piece_line(quantity: 999) ])

      expect(parser.validate_article_count(result)).to be(true)
      expect(parser.warnings).to be_empty
    end

    it "strictly counts piece quantities and non-piece item lines" do
      result = envelope(receipt: { declared_article_count: 4 }, lines: counted_article_lines)

      expect(parser.validate_article_count(result)).to be(true)
      expect(parser.warnings).to be_empty
    end

    it "adds a structured warning when the declared count differs" do
      result = envelope(receipt: { declared_article_count: 3 }, lines: [ piece_line(quantity: 1), kg_line ])

      expect(parser.validate_article_count(result)).to be(false)
      expect(parser.warnings).to contain_exactly(article_count_warning)
    end
  end

  describe "#validate_payments_sum" do
    it "passes when payments match within the one-cent monetary tolerance" do
      result = envelope(receipt: { total_cents: 1_000 }, payments: [ { amount_cents: 601 }, { amount_cents: 400 } ])

      expect(parser.validate_payments_sum(result)).to be(true)
      expect(parser.warnings).to be_empty
    end

    it "adds a structured warning when payments differ by more than one cent" do
      result = envelope(receipt: { total_cents: 1_000 }, payments: [ { amount_cents: 990 } ])

      expect(parser.validate_payments_sum(result)).to be(false)
      expect(parser.warnings).to contain_exactly(payment_warning)
    end
  end

  describe "record compatibility" do
    let(:receipt_record) { create_receipt(total_cents: 500, declared_article_count: 1) }
    let(:line_record) { create_receipt_line(receipt: receipt_record, total_cents: 500) }
    let(:payment_record) { create_receipt_payment(receipt: receipt_record, amount_cents: 500) }

    it "can validate Active Record instances as well as parser attribute hashes" do
      result = envelope(receipt: receipt_record, lines: [ line_record ], payments: [ payment_record ])

      expect(parser.validate_totals_sum(result)).to be(true)
      expect(parser.validate_article_count(result)).to be(true)
      expect(parser.validate_payments_sum(result)).to be(true)
    end
  end

  describe "shared parser helpers" do
    it "parses cents from comma or dot decimal separators" do
      expect(parser.cents_from("12,34")).to eq(1_234)
      expect(parser.cents_from("12.34")).to eq(1_234)
      expect(parser.cents_from("-12,34")).to eq(-1_234)
    end

    it "resolves full and abbreviated French month names" do
      expect(parser.french_month_number("janvier")).to eq(1)
      expect(parser.french_month_number("janv.")).to eq(1)
      expect(parser.french_month_number("déc.")).to eq(12)
    end

    it "maps raw payment labels to normalized categories" do
      expect(parser.payment_category("CB SANS CONTACT VX")).to eq("bank_card")
      expect(parser.payment_category("CB TRD 4COINS SANS CONTACT")).to eq("tickets_restaurant")
      expect(parser.payment_category("CB Web C&C SUE")).to eq("web")
      expect(parser.payment_category("ESPECES")).to eq("cash")
      expect(parser.payment_category("Bon achat carte")).to eq("other")
    end
  end

  def envelope(receipt: {}, lines: [], promotions: [], payments: [], warnings: parser.warnings)
    parser.result_envelope(
      receipt: receipt,
      lines: lines,
      promotions: promotions,
      payments: payments,
      warnings: warnings
    )
  end

  def receipt_attributes
    { total_cents: 1_234 }
  end

  def result_input_attributes
    {
      receipt: receipt_attributes,
      lines: line_attributes,
      promotions: promotion_attributes,
      payments: payment_attributes
    }
  end

  def result_output_attributes
    result_input_attributes.merge(warnings: [])
  end

  def line_attributes
    [ { total_cents: 1_234 } ]
  end

  def promotion_attributes
    [ { program: "loyalty" } ]
  end

  def payment_attributes
    [ { amount_cents: 1_234 } ]
  end

  def callable_parser(total_cents: 500, declared_article_count: 2, line_totals: [ 200, 300 ], line_quantities: [ 1, 1 ], payment_amounts: [ 500 ])
    Class.new(described_class) do
      define_method(:receipt_total_cents) { total_cents }
      define_method(:receipt_declared_article_count) { declared_article_count }
      define_method(:parser_line_totals) { line_totals }
      define_method(:parser_line_quantities) { line_quantities }
      define_method(:parser_payment_amounts) { payment_amounts }

      private

      def receipt_attributes
        {
          total_cents: receipt_total_cents,
          declared_article_count: receipt_declared_article_count,
          parser_status: "parsed",
          parser_warnings: warnings
        }
      end

      def parsed_lines
        parser_line_totals.zip(parser_line_quantities).map do |total_cents, quantity|
          { total_cents: total_cents, kind: "item", unit_of_measure: "piece", quantity: quantity }
        end
      end

      def payment_attributes
        parser_payment_amounts.map { |amount_cents| { amount_cents: amount_cents } }
      end
    end
  end

  def piece_line(quantity:)
    { kind: "item", unit_of_measure: "piece", quantity: quantity }
  end

  def kg_line
    { kind: "item", unit_of_measure: "kg", quantity: 0.325 }
  end

  def counted_article_lines
    [ piece_line(quantity: 3), kg_line, { kind: "fee", unit_of_measure: "piece", quantity: 1 } ]
  end

  def parser_exception_warning
    {
      code: "parser_exception",
      validator: nil,
      detail: "Parser failed",
      value: nil
    }
  end

  def totals_warning
    {
      code: "totals_sum_mismatch",
      validator: "validate_totals_sum",
      detail: "Line totals differ from receipt total by -3 cents",
      value: -3
    }
  end

  def article_count_warning
    {
      code: "article_count_mismatch",
      validator: "validate_article_count",
      detail: "Article count differs from declared count by -1",
      value: -1
    }
  end

  def payment_warning
    {
      code: "payments_sum_mismatch",
      validator: "validate_payments_sum",
      detail: "Payment sum differs from receipt total by -10 cents",
      value: -10
    }
  end
end
