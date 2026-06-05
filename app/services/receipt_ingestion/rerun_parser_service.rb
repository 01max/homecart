module ReceiptIngestion
  # Replaces a receipt graph with a fresh parse from the latest successful text.
  #
  # Re-running keeps the existing receipt identity while replacing parser-owned
  # attributes and child records. Source evidence remains append-only.
  class RerunParserService < ApplicationService
    Result = Data.define(:receipt, :lines, :promotions, :payments)

    MissingSuccessfulTextExtractionError = Class.new(StandardError)
    MissingPromotionLinkedLineError = ParseService::MissingPromotionLinkedLineError

    # @param receipt [Receipt] persisted receipt to replace with fresh parser output
    # @param parser_format [String, nil] parser format to use; defaults to receipt format
    # @param parser_registry [Module] registry object responding to `.for(format)`
    # @param duplicate_detector [Class] duplicate-detection service
    # @param validator [Class] post-persistence validation service
    def initialize(
      receipt:,
      parser_format: nil,
      parser_registry: Parser::Registry,
      duplicate_detector: DetectDuplicateService,
      validator: ValidateParseService
    )
      @receipt = receipt
      @parser_format = parser_format.presence || receipt.parser_format_before_type_cast
      @parser_registry = parser_registry
      @duplicate_detector = duplicate_detector
      @validator = validator
    end

    # @return [Result] updated receipt and freshly persisted child records
    def call
      parser_result = parse_text

      ActiveRecord::Base.transaction do
        replace_receipt(parser_result)
        replace_children(parser_result)
      end
    end

    private

    attr_reader :receipt, :parser_format, :parser_registry, :duplicate_detector, :validator

    def parse_text
      parser = parser_registry.for(parser_format).new(text: latest_successful_text_extraction.text)
      parser.call
    rescue MissingSuccessfulTextExtractionError
      raise
    rescue StandardError => e
      failed_parse_result(e)
    end

    def latest_successful_text_extraction
      @latest_successful_text_extraction ||= receipt
        .source_document
        .text_extractions
        .where(success: true)
        .order(ran_at: :desc, id: :desc)
        .first || raise_missing_successful_text_extraction
    end

    def raise_missing_successful_text_extraction
      raise MissingSuccessfulTextExtractionError,
        I18n.t("receipt_ingestion.rerun_parser.errors.missing_successful_text_extraction")
    end

    def failed_parse_result(error)
      warning = {
        code: "parser_exception",
        validator: nil,
        detail: I18n.t("receipt_ingestion.parser_warnings.parser_exception.detail", detail: error.message),
        value: nil
      }
      Parser::Base.validate_warning!(warning)

      Parser::Base::Result.new(
        receipt: { parser_status: "needs_review" },
        lines: [],
        promotions: [],
        payments: [],
        warnings: [ warning ]
      )
    end

    def replace_receipt(parser_result)
      receipt.assign_attributes(
        parser_result.receipt.to_h.merge(
          store: receipt.store,
          source_document: receipt.source_document,
          text_extraction: latest_successful_text_extraction,
          parser_format: parser_format,
          parser_warnings: parser_result.warnings
        )
      )
      duplicate_detector.call(receipt: receipt)
      receipt.save!
    end

    def replace_children(parser_result)
      destroy_children
      return Result.new(receipt: receipt, lines: [], promotions: [], payments: []) if parser_exception_result?(parser_result)

      lines_by_position = create_lines(parser_result.lines)
      promotions = create_promotions(parser_result.promotions, lines_by_position)
      payments = create_payments(parser_result.payments)
      validator.call(receipt: receipt)

      Result.new(receipt: receipt, lines: lines_by_position.values, promotions: promotions, payments: payments)
    end

    def destroy_children
      ReceiptPromotion.where(receipt: receipt).destroy_all
      ReceiptPayment.where(receipt: receipt).destroy_all
      ReceiptLine.where(receipt: receipt).destroy_all
    end

    def parser_exception_result?(parser_result)
      parser_result.warnings.any? { |warning| warning[:code] == "parser_exception" }
    end

    def create_lines(line_attributes)
      line_attributes.each_with_object({}) do |attributes, lines_by_position|
        line = receipt.receipt_lines.create!(attributes)
        lines_by_position[line.position] = line
      end
    end

    def create_promotions(promotion_attributes, lines_by_position)
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

    def create_payments(payment_attributes)
      payment_attributes.map do |attributes|
        receipt.receipt_payments.create!(attributes)
      end
    end
  end
end
