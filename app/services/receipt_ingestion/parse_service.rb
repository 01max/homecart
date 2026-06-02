module ReceiptIngestion
  class ParseService < ApplicationService
    Result = Data.define(:receipt, :lines, :promotions, :payments)

    MissingPromotionLinkedLineError = Class.new(StandardError)

    def initialize(
      text_extraction:,
      parser_format: text_extraction.source_document.parser_format,
      parser_registry: Parser::Registry,
      validator: ValidateParseService
    )
      @text_extraction = text_extraction
      @parser_format = parser_format
      @parser_registry = parser_registry
      @validator = validator
    end

    def call
      parser_result = parse_text

      ActiveRecord::Base.transaction do
        receipt = create_receipt(parser_result)
        lines_by_position = create_lines(receipt, parser_result.lines)
        promotions = create_promotions(receipt, parser_result.promotions, lines_by_position)
        payments = create_payments(receipt, parser_result.payments)
        validator.call(receipt: receipt)

        Result.new(receipt: receipt, lines: lines_by_position.values, promotions: promotions, payments: payments)
      end
    end

    private

    attr_reader :text_extraction, :parser_format, :parser_registry, :validator

    delegate :source_document, to: :text_extraction

    def parse_text
      parser_registry.for(parser_format).new(text: text_extraction.text).call
    end

    def create_receipt(parser_result)
      Receipt.create!(
        parser_result.receipt.to_h.merge(
          store: source_document.store,
          source_document: source_document,
          text_extraction: text_extraction,
          parser_format: parser_format,
          parser_warnings: parser_result.warnings
        )
      )
    end

    def create_lines(receipt, line_attributes)
      line_attributes.each_with_object({}) do |attributes, lines_by_position|
        line = receipt.receipt_lines.create!(attributes)
        lines_by_position[line.position] = line
      end
    end

    def create_promotions(receipt, promotion_attributes, lines_by_position)
      promotion_attributes.map do |attributes|
        receipt.receipt_promotions.create!(promotion_attributes_for(attributes, lines_by_position))
      end
    end

    def promotion_attributes_for(attributes, lines_by_position)
      attributes = attributes.to_h.symbolize_keys
      linked_line_position = attributes.delete(:linked_line_position)
      return attributes if linked_line_position.blank?

      attributes.merge(linked_line: linked_line_for(linked_line_position, lines_by_position))
    end

    def linked_line_for(position, lines_by_position)
      lines_by_position.fetch(position) do
        raise MissingPromotionLinkedLineError,
              I18n.t("receipt_ingestion.parse.errors.missing_promotion_linked_line", position: position)
      end
    end

    def create_payments(receipt, payment_attributes)
      payment_attributes.map do |attributes|
        receipt.receipt_payments.create!(attributes)
      end
    end
  end
end
