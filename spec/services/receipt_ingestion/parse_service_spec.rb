require "rails_helper"

RSpec.describe ReceiptIngestion::ParseService do
  def parser_registry_for(parser_class)
    Class.new do
      class << self
        attr_accessor :requested_format, :parser_class

        def for(format)
          self.requested_format = format
          parser_class
        end
      end
    end.tap { |registry| registry.parser_class = parser_class }
  end

  def parser_class_for(parser_result)
    Class.new do
      class << self
        attr_accessor :calls, :parser_result
      end

      self.calls = []
      self.parser_result = parser_result

      def initialize(text:)
        @text = text
      end

      def call
        self.class.calls << @text
        self.class.parser_result
      end
    end
  end

  def parse_context(parser_result: build_parser_result, text_extraction: create_text_extraction)
    parser_class = parser_class_for(parser_result)
    parser_registry = parser_registry_for(parser_class)
    result = described_class.call(
      text_extraction: text_extraction,
      parser_format: "leclerc.paper.v1",
      parser_registry: parser_registry
    )

    { parser_class: parser_class, parser_registry: parser_registry, result: result, text_extraction: text_extraction }
  end

  def build_parser_result(receipt: receipt_attributes, lines: line_attributes, promotions: promotion_attributes, payments: payment_attributes, warnings: [])
    Parser::Base::Result.new(
      receipt: receipt,
      lines: lines,
      promotions: promotions,
      payments: payments,
      warnings: warnings
    )
  end

  def expect_persisted_receipt(receipt, text_extraction)
    expect(receipt).to have_attributes(
      store: text_extraction.source_document.store,
      source_document: text_extraction.source_document,
      text_extraction: text_extraction,
      total_cents: 500,
      parser_status: "parsed"
    )
    expect(receipt).to be_parser_format_leclerc_paper_v1
  end

  def expect_persisted_children(result)
    expect(result.lines.map(&:label)).to contain_exactly("ARTICLE A", "ARTICLE B")
    expect(result.payments.map(&:raw_label)).to contain_exactly("CARTE BANCAIRE")
    expect(result.promotions.sole.linked_line).to eq(result.lines.find { |line| line.position == 1 })
  end

  def expect_no_receipt_graph
    expect(Receipt.count).to eq(0)
    expect(ReceiptLine.count).to eq(0)
    expect(ReceiptPromotion.count).to eq(0)
    expect(ReceiptPayment.count).to eq(0)
  end

  def receipt_attributes
    {
      purchased_at: Time.zone.local(2026, 6, 1, 12, 30, 0),
      register_number: "101",
      ticket_number: "12345",
      cashier_code: "9999",
      total_cents: 500,
      declared_article_count: 2,
      parser_status: "parsed"
    }
  end

  def line_attributes
    [
      {
        position: 1,
        raw_text: "ARTICLE A 2,00",
        label: "ARTICLE A",
        total_cents: 200,
        quantity: BigDecimal("1"),
        unit_of_measure: "piece",
        kind: "item"
      },
      {
        position: 2,
        raw_text: "ARTICLE B 3,00",
        label: "ARTICLE B",
        total_cents: 300,
        quantity: BigDecimal("1"),
        unit_of_measure: "piece",
        kind: "item"
      }
    ]
  end

  def promotion_attributes
    [
      {
        program: "auchan_waaoh",
        unit: "euro_cents",
        delta: 40,
        label: "ARTICLE A",
        kind: "loyalty_credit",
        linked_line_position: 1,
        linking_method: "parser_inferred"
      }
    ]
  end

  def payment_attributes
    [
      {
        position: 1,
        raw_label: "CARTE BANCAIRE",
        category: "bank_card",
        amount_cents: 500
      }
    ]
  end

  def parser_notice_warning
    {
      code: "parser_notice",
      validator: nil,
      detail: "Parser noticed something",
      value: nil
    }
  end

  it "looks up the parser, runs it, and persists the parsed receipt graph" do
    context = parse_context

    expect(context.fetch(:parser_registry).requested_format).to eq("leclerc.paper.v1")
    expect(context.fetch(:parser_class).calls).to contain_exactly(context.fetch(:text_extraction).text)
    expect_persisted_receipt(context.fetch(:result).receipt, context.fetch(:text_extraction))
    expect_persisted_children(context.fetch(:result))
  end

  it "persists parser warnings onto the receipt" do
    result = parse_context(parser_result: build_parser_result(warnings: [ parser_notice_warning ])).fetch(:result)

    expect(result.receipt.parser_warnings).to contain_exactly(
      a_hash_including("code" => "parser_notice", "detail" => "Parser noticed something")
    )
  end

  it "rolls back the whole parse when one child record cannot be persisted" do
    invalid_payments = [ payment_attributes.first.merge(amount_cents: 0) ]
    result = build_parser_result(payments: invalid_payments)

    expect do
      parse_context(parser_result: result)
    end.to raise_error(ActiveRecord::RecordInvalid, /Amount cents/)

    expect_no_receipt_graph
  end
end
