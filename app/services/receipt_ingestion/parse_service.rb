module ReceiptIngestion
  # Persists parser output into the receipt graph.
  #
  # The service is the parsing pipeline's persistence boundary: it selects the
  # parser, copies store/format from the {SourceDocument}, creates receipt child
  # records transactionally, runs duplicate detection, and applies validators.
  class ParseService < ApplicationService
    Result = Data.define(:receipt, :lines, :promotions, :payments)

    MissingPromotionLinkedLineError = Class.new(StandardError)
    UnclassifiedSourceDocumentError = Class.new(StandardError)

    # @param text_extraction [TextExtraction] successful extraction to parse
    # @param parser_format [String, nil] optional registry key; defaults to source document format
    # @param parser_registry [Module] registry object responding to `.for(format)`
    # @param duplicate_detector [Class] duplicate-detection service
    # @param validator [Class] post-persistence validation service
    def initialize(
      text_extraction:,
      parser_format: nil,
      parser_registry: Parser::Registry,
      duplicate_detector: DetectDuplicateService,
      validator: ValidateParseService
    )
      @text_extraction = text_extraction
      @parser_format_override = parser_format.presence
      @parser_registry = parser_registry
      @duplicate_detector = duplicate_detector
      @validator = validator
    end

    # @return [Result] persisted receipt and child records
    # @raise [MissingPromotionLinkedLineError] when parser promotion references an unknown line
    # @raise [UnclassifiedSourceDocumentError] when source classification is incomplete
    # @raise [ReceiptIngestion::DetectDuplicateService::DuplicateReceiptError] on strict duplicates
    # @raise [ActiveRecord::RecordInvalid] when parser output cannot be persisted
    def call
      ensure_source_document_classified!

      parser_result = parse_text

      ActiveRecord::Base.transaction do
        receipt = create_receipt(parser_result)
        return Result.new(receipt: receipt, lines: [], promotions: [], payments: []) if parser_exception_result?(parser_result)

        lines_by_position = create_lines(receipt, parser_result.lines)
        promotions = create_promotions(receipt, parser_result.promotions, lines_by_position)
        payments = create_payments(receipt, parser_result.payments)
        validator.call(receipt: receipt)

        Result.new(receipt: receipt, lines: lines_by_position.values, promotions: promotions, payments: payments)
      end
    end

    private

    attr_reader :text_extraction, :parser_format_override, :parser_registry, :duplicate_detector, :validator

    delegate :source_document, to: :text_extraction

    def ensure_source_document_classified!
      return if source_document.classified? && source_document.store.present? && source_document.parser_format.present?

      raise UnclassifiedSourceDocumentError,
            I18n.t("receipt_ingestion.parse.errors.unclassified_source_document")
    end

    def parse_text
      parser = parser_registry.for(parser_format).new(text: text_extraction.text)
      parser.call
    rescue StandardError => e
      failed_parse_result(e)
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

    def parser_exception_result?(parser_result)
      parser_result.warnings.any? { |warning| warning[:code] == "parser_exception" }
    end

    def source_document_parser_format
      SourceDocument::PARSER_FORMATS.fetch(source_document.parser_format.to_sym)
    end

    def parser_format
      parser_format_override || source_document_parser_format
    end

    def create_receipt(parser_result)
      Receipt.new(
        parser_result.receipt.to_h.merge(
          store: source_document.store,
          source_document: source_document,
          text_extraction: text_extraction,
          parser_format: parser_format,
          parser_warnings: parser_result.warnings
        )
      ).tap do |receipt|
        duplicate_detector.call(receipt: receipt)
        receipt.save!
      end
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
