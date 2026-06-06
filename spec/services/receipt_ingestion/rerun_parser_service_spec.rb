require "rails_helper"

RSpec.describe ReceiptIngestion::RerunParserService do
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

  def build_parser_result(receipt: receipt_attributes, lines: line_attributes, promotions: promotion_attributes, payments: payment_attributes, warnings: [])
    Parser::Base::Result.new(
      receipt: receipt,
      lines: lines,
      promotions: promotions,
      payments: payments,
      warnings: warnings
    )
  end

  def receipt_attributes(declared_article_count: 2)
    {
      purchased_at: Time.zone.local(2026, 6, 2, 10, 30, 0),
      register_number: "202",
      ticket_number: "54321",
      cashier_code: "D34",
      total_cents: 500,
      declared_article_count: declared_article_count,
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
        kind: "loyalty_cash_credit",
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

  def create_receipt_with_stale_parse
    source_document = create(:source_document)
    older_extraction = create(:text_extraction, source_document: source_document, text: "older text", ran_at: 2.days.ago)
    create(:text_extraction, source_document: source_document, text: "latest text", ran_at: 1.hour.ago)
    store = create(:store)
    receipt = create(
      :receipt,
      store: store,
      source_document: source_document,
      text_extraction: older_extraction,
      parser_format: "leclerc.paper.v1",
      total_cents: 999,
      declared_article_count: 1,
      parser_status: "reviewed"
    )
    old_line = create(:receipt_line, receipt: receipt, position: 1, label: "OLD LINE", total_cents: 999)
    create(:receipt_promotion, receipt: receipt, linked_line: old_line, linking_method: "parser_inferred")
    create(:receipt_payment, receipt: receipt, position: 1, raw_label: "OLD PAYMENT", amount_cents: 999)
    receipt
  end

  def rerun_context(receipt: create_receipt_with_stale_parse, parser_result: build_parser_result, parser_format: "u.paper.v2")
    parser_class = parser_class_for(parser_result)
    parser_registry = parser_registry_for(parser_class)

    result = described_class.call(
      receipt: receipt,
      parser_format: parser_format,
      parser_registry: parser_registry
    )

    { parser_class: parser_class, parser_registry: parser_registry, receipt: receipt.reload, result: result }
  end

  def expect_parser_to_use_latest_text(context)
    expect(context.fetch(:parser_registry).requested_format).to eq("u.paper.v2")
    expect(context.fetch(:parser_class).calls).to contain_exactly("latest text")
  end

  def expect_receipt_to_be_reparsed(context)
    receipt = context.fetch(:receipt)

    expect(context.fetch(:result).receipt).to eq(receipt)
    expect(receipt).to have_attributes(total_cents: 500, register_number: "202", parser_status: "parsed")
    expect(receipt).to be_parser_format_u_paper_v2
    expect(receipt.text_extraction.text).to eq("latest text")
  end

  def expect_children_to_be_replaced(receipt)
    expect(receipt.receipt_lines.pluck(:label)).to contain_exactly("ARTICLE A", "ARTICLE B")
    expect(receipt.receipt_promotions.sole.linked_line).to eq(receipt.receipt_lines.find_by!(position: 1))
    expect(receipt.receipt_payments.sole.raw_label).to eq("CARTE BANCAIRE")
  end

  def expect_parser_exception_rerun(result, receipt)
    expect(result).to have_attributes(lines: [], promotions: [], payments: [])
    expect(receipt.reload).to be_needs_review
    expect(receipt.parser_warnings).to contain_exactly(a_hash_including("code" => "parser_exception"))
    expect(receipt.receipt_lines).to be_empty
    expect(receipt.receipt_promotions).to be_empty
    expect(receipt.receipt_payments).to be_empty
  end

  def receipt_without_successful_extraction
    source_document = create(:source_document)
    failed_extraction = create(:text_extraction, :failed, source_document: source_document)

    create(:receipt, source_document: source_document, text_extraction: failed_extraction)
  end

  it "uses the latest successful text extraction and replaces the existing receipt graph" do
    context = rerun_context

    expect_parser_to_use_latest_text(context)
    expect_receipt_to_be_reparsed(context)
    expect_children_to_be_replaced(context.fetch(:receipt))
  end

  it "keeps the reviewed store instead of copying the source document store" do
    receipt = rerun_context.fetch(:receipt)

    expect(receipt.store).not_to eq(receipt.source_document.store)
  end

  it "routes validator failures through the persisted validator service" do
    parser_result = build_parser_result(receipt: receipt_attributes(declared_article_count: 3))
    receipt = rerun_context(parser_result: parser_result).fetch(:receipt)

    expect(receipt).to be_needs_review
    expect(receipt.parser_warnings).to contain_exactly(
      a_hash_including("code" => "article_count_mismatch", "validator" => "validate_article_count")
    )
  end

  it "replaces old children with an empty review receipt when the parser raises" do
    parser_class = parser_class_raising(StandardError.new("unexpected parser bug"))
    parser_registry = parser_registry_for(parser_class)
    receipt = create_receipt_with_stale_parse

    result = described_class.call(receipt: receipt, parser_registry: parser_registry)

    expect_parser_exception_rerun(result, receipt)
  end

  it "raises a localized error when no successful extraction exists" do
    expect do
      described_class.call(receipt: receipt_without_successful_extraction)
    end.to raise_error(
      described_class::MissingSuccessfulTextExtractionError,
      I18n.t("receipt_ingestion.rerun_parser.errors.missing_successful_text_extraction")
    )
  end
end
