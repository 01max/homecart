module ReceiptIngestion
  # Classifies a source document from extracted receipt text.
  #
  # The service owns the persistence boundary for source-detection attempts.
  # Rule-specific parser and store detection are added behind the selection
  # methods so the result envelope stays stable as the detector grows.
  class DetectSourceDocumentService < ApplicationService
    Selection = Data.define(:value, :confidence, :evidence)
    Result = Data.define(
      :status,
      :parser_format,
      :parser_confidence,
      :store,
      :store_confidence,
      :evidence,
      :detection,
      :source_document
    ) do
      def classified?
        status == SourceDocumentDetection::STATUSES.fetch(:classified)
      end

      def needs_classification?
        status == SourceDocumentDetection::STATUSES.fetch(:needs_classification)
      end
    end

    # @param text_extraction [TextExtraction] extraction attempt used as detection evidence
    def initialize(text_extraction:)
      @text_extraction = text_extraction
      @source_document = text_extraction.source_document
    end

    # @return [Result] persisted detection plus the selected source fields
    # @raise [ActiveRecord::RecordInvalid] when selected fields cannot be persisted
    def call
      parser_selection = select_parser_format
      store_selection = select_store
      status = status_for(parser_selection: parser_selection, store_selection: store_selection)
      evidence = parser_selection.evidence + store_selection.evidence

      ActiveRecord::Base.transaction do
        detection = create_detection(
          status: status,
          parser_selection: parser_selection,
          store_selection: store_selection,
          evidence: evidence
        )
        update_source_document(status: status, parser_selection: parser_selection, store_selection: store_selection)

        Result.new(
          status: status,
          parser_format: parser_selection.value,
          parser_confidence: parser_selection.confidence,
          store: store_selection.value,
          store_confidence: store_selection.confidence,
          evidence: evidence,
          detection: detection,
          source_document: source_document.reload
        )
      end
    end

    private

    attr_reader :text_extraction, :source_document

    def select_parser_format
      parser_format = explicit_parser_format
      return manual_selection(parser_format, explicit_parser_format_evidence(parser_format)) if parser_format.present?

      none_selection(code: "parser_format_detection_pending")
    end

    def select_store
      return manual_selection(source_document.store, explicit_store_evidence) if source_document.store.present?

      none_selection(code: "store_detection_pending")
    end

    def explicit_parser_format
      SourceDocument.parser_formats.fetch(source_document.parser_format) if source_document.parser_format.present?
    end

    def manual_selection(value, evidence)
      Selection.new(value, SourceDocumentDetection::CONFIDENCES.fetch(:manual), [ evidence ])
    end

    def none_selection(code:)
      Selection.new(nil, SourceDocumentDetection::CONFIDENCES.fetch(:none), [ { "code" => code } ])
    end

    def explicit_parser_format_evidence(parser_format)
      {
        "code" => "explicit_parser_format",
        "parser_format" => parser_format
      }
    end

    def explicit_store_evidence
      {
        "code" => "explicit_store",
        "store_id" => source_document.store_id
      }
    end

    def status_for(parser_selection:, store_selection:)
      if parser_selection.value.present? && store_selection.value.present?
        SourceDocumentDetection::STATUSES.fetch(:classified)
      else
        SourceDocumentDetection::STATUSES.fetch(:needs_classification)
      end
    end

    def create_detection(status:, parser_selection:, store_selection:, evidence:)
      SourceDocumentDetection.create!(
        source_document: source_document,
        text_extraction: text_extraction,
        status: status,
        parser_format: parser_selection.value,
        parser_confidence: parser_selection.confidence,
        store: store_selection.value,
        store_confidence: store_selection.confidence,
        evidence: evidence
      )
    end

    def update_source_document(status:, parser_selection:, store_selection:)
      source_document.update!(
        source_detection_status: status,
        parser_format: parser_selection.value,
        store: store_selection.value
      )
    end
  end
end
