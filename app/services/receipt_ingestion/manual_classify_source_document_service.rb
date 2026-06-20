module ReceiptIngestion
  # Applies a user-supplied source classification and resumes parsing.
  class ManualClassifySourceDocumentService < ApplicationService
    Result = Data.define(:source_document, :text_extraction, :detection)

    MissingSuccessfulTextExtractionError = Class.new(StandardError)

    # @param source_document [SourceDocument] source document to classify
    # @param store [Store] user-selected store
    # @param parser_format [String, Symbol] user-selected parser format
    # @param parse_job_class [Class] job class used to resume parsing
    def initialize(source_document:, store:, parser_format:, parse_job_class: Receipt::ParseJob)
      @source_document = source_document
      @store = store
      @parser_format = normalize_parser_format(parser_format)
      @parse_job_class = parse_job_class
    end

    # @return [Result] classified source document, evidence text extraction, and manual detection
    def call
      result = nil

      ActiveRecord::Base.transaction do
        text_extraction = latest_successful_text_extraction
        source_document.update!(
          store: store,
          parser_format: parser_format,
          source_detection_status: "classified"
        )
        detection = create_manual_detection(text_extraction)
        result = Result.new(source_document: source_document.reload, text_extraction: text_extraction, detection: detection)
      end

      parse_job_class.perform_later(result.text_extraction.id)
      result
    end

    private

    attr_reader :source_document, :store, :parser_format, :parse_job_class

    def normalize_parser_format(parser_format)
      SourceDocument.parser_formats.fetch(parser_format.to_s, parser_format)
    end

    def latest_successful_text_extraction
      source_document
        .text_extractions
        .where(success: true)
        .order(ran_at: :desc, created_at: :desc)
        .first || raise_missing_successful_text_extraction
    end

    def raise_missing_successful_text_extraction
      raise MissingSuccessfulTextExtractionError,
        I18n.t("receipt_ingestion.manual_classify_source_document.errors.missing_successful_text_extraction")
    end

    def create_manual_detection(text_extraction)
      SourceDocumentDetection.create!(
        source_document: source_document,
        text_extraction: text_extraction,
        status: "classified",
        parser_format: parser_format,
        parser_confidence: "manual",
        store: store,
        store_confidence: "manual",
        evidence: manual_evidence
      )
    end

    def manual_evidence
      [
        {
          "code" => "manual_classification",
          "store_id" => store.id,
          "parser_format" => parser_format
        }
      ]
    end
  end
end
