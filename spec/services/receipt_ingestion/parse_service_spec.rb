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

  def parser_class_raising(error)
    Class.new do
      class << self
        attr_accessor :calls, :error
      end

      self.calls = []
      self.error = error

      def initialize(text:)
        @text = text
      end

      def call
        self.class.calls << @text
        raise self.class.error
      end
    end
  end

  def parse_context(parser_result: build_parser_result, text_extraction: create(:text_extraction), parser_format: "leclerc.paper.v1")
    parser_class = parser_class_for(parser_result)
    parse_context_for_parser_class(parser_class, text_extraction: text_extraction, parser_format: parser_format)
  end

  def parse_context_for_parser_class(parser_class, text_extraction: create(:text_extraction), parser_format: "leclerc.paper.v1")
    parser_registry = parser_registry_for(parser_class)
    service_arguments = {
      text_extraction: text_extraction,
      parser_registry: parser_registry
    }
    service_arguments[:parser_format] = parser_format if parser_format
    result = described_class.call(**service_arguments)

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

  def expect_only_existing_receipt_graph
    expect(Receipt.count).to eq(1)
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

  def create_existing_receipt_for_duplicate(store:, purchased_at:, register_number: nil, ticket_number: nil)
    create(:receipt,
      store: store,
      purchased_at: purchased_at,
      total_cents: 500,
      parser_status: "parsed"
    ).tap do |receipt|
      receipt.update!(register_number: register_number, ticket_number: ticket_number)
    end
  end

  def text_extraction_for_store(store)
    source_document = create(:source_document, store: store)
    create(:text_extraction, source_document: source_document)
  end

  def text_extraction_with_existing_exact_duplicate(store:, purchased_at:)
    create_existing_receipt_for_duplicate(
      store: store,
      purchased_at: purchased_at,
      register_number: "101",
      ticket_number: "12345"
    )
    text_extraction_for_store(store)
  end

  def expect_suspected_duplicate_warning(receipt, duplicate)
    expect(receipt.parser_warnings).to contain_exactly(
      a_hash_including(
        "code" => "suspected_duplicate",
        "detail" => "Possible duplicate of receipt #{duplicate.id}"
      )
    )
  end

  def expect_duplicate_parse_rejected(text_extraction)
    expect do
      parse_context(text_extraction: text_extraction)
    end.to raise_error(ReceiptIngestion::DetectDuplicateService::DuplicateReceiptError)
  end

  def expect_parser_exception_warning(receipt)
    expect(receipt.parser_warnings).to contain_exactly(
      a_hash_including(
        "code" => "parser_exception",
        "detail" => "Parser failed: unexpected parser bug"
      )
    )
  end

  it "looks up the parser, runs it, and persists the parsed receipt graph" do
    context = parse_context

    expect(context.fetch(:parser_registry).requested_format).to eq("leclerc.paper.v1")
    expect(context.fetch(:parser_class).calls).to contain_exactly(context.fetch(:text_extraction).text)
    expect_persisted_receipt(context.fetch(:result).receipt, context.fetch(:text_extraction))
    expect_persisted_children(context.fetch(:result))
  end

  it "copies store and parser format from the source document instead of trusting parser attributes" do
    source_document = create(:source_document, store: create(:store), parser_format: "u.paper.v2")
    text_extraction = create(:text_extraction, source_document: source_document)
    parser_receipt = receipt_attributes.merge(store: create(:store), parser_format: "auchan.paper.v1")

    context = parse_context(parser_result: build_parser_result(receipt: parser_receipt), text_extraction: text_extraction, parser_format: nil)

    expect(context.fetch(:parser_registry).requested_format).to eq("u.paper.v2")
    expect(context.fetch(:result).receipt.store).to eq(source_document.store)
    expect(context.fetch(:result).receipt).to be_parser_format_u_paper_v2
  end

  it "persists parser warnings onto the receipt" do
    result = parse_context(parser_result: build_parser_result(warnings: [ parser_notice_warning ])).fetch(:result)

    expect(result.receipt.parser_warnings).to contain_exactly(
      a_hash_including("code" => "parser_notice", "detail" => "Parser noticed something")
    )
  end

  it "routes validator failures to review after persistence" do
    parser_result = build_parser_result(receipt: receipt_attributes.merge(declared_article_count: 3))

    result = parse_context(parser_result: parser_result).fetch(:result)

    expect(result.receipt).to be_needs_review
    expect(result.receipt.parser_warnings).to contain_exactly(
      a_hash_including("code" => "article_count_mismatch", "validator" => "validate_article_count", "value" => -1)
    )
    expect(result.lines.size).to eq(2)
  end

  it "flags suspected duplicate receipts for review after persistence" do
    store = create(:store)
    duplicate = create_existing_receipt_for_duplicate(store: store, purchased_at: Time.zone.local(2026, 6, 1, 9, 15, 0))
    text_extraction = text_extraction_for_store(store)

    result = parse_context(text_extraction: text_extraction).fetch(:result)

    expect(result.receipt).to be_needs_review
    expect_suspected_duplicate_warning(result.receipt, duplicate)
  end

  it "rejects an exact composite duplicate before persisting a new receipt graph" do
    store = create(:store)
    text_extraction = text_extraction_with_existing_exact_duplicate(
      store: store,
      purchased_at: Time.zone.local(2026, 6, 1, 12, 30, 0)
    )

    expect_duplicate_parse_rejected(text_extraction)

    expect_only_existing_receipt_graph
  end

  it "routes parser exceptions to review without persisting child records" do
    parser_class = parser_class_raising(StandardError.new("unexpected parser bug"))

    context = parse_context_for_parser_class(parser_class)
    receipt = context.fetch(:result).receipt

    expect(receipt).to be_persisted
    expect(receipt).to be_needs_review
    expect_parser_exception_warning(receipt)
    expect(context.fetch(:result)).to have_attributes(lines: [], promotions: [], payments: [])
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
