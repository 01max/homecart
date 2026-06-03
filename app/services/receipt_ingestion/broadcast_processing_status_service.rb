module ReceiptIngestion
  # Broadcasts receipt-ingestion pipeline state to the visible Hotwire surfaces.
  #
  # Jobs and services call this explicitly after workflow transitions. Keeping
  # the broadcast logic here avoids model callbacks while giving the source
  # document page and receipt listings one place to agree on stream names.
  class BroadcastProcessingStatusService < ApplicationService
    class << self
      # @param parser_status [String, nil] optional receipt status filter
      # @return [String] Turbo stream name for a receipt index view
      def receipts_stream_name(parser_status = nil)
        parser_status.present? ? "receipts:#{parser_status}" : "receipts"
      end

      # @param parser_status [String, nil] optional receipt status filter
      # @return [String] DOM id for the replaceable receipt list
      def receipts_list_dom_id(parser_status = nil)
        parser_status.present? ? "receipts_list_#{parser_status}" : "receipts_list"
      end
    end

    # @param source_document [SourceDocument] source document whose page updates
    # @param text_extraction [TextExtraction, nil] latest extraction, when known
    # @param receipt [Receipt, nil] parsed receipt, when known
    # @param extraction_state [String, nil] explicit extraction state
    # @param parsing_state [String, nil] explicit parsing state
    def initialize(
      source_document:,
      text_extraction: nil,
      receipt: nil,
      extraction_state: nil,
      parsing_state: nil
    )
      @source_document = source_document
      @text_extraction = text_extraction
      @receipt = receipt
      @extraction_state = extraction_state
      @parsing_state = parsing_state
    end

    # @return [void]
    def call
      broadcast_source_document_status
      broadcast_receipt_lists if current_receipt
    end

    private

    attr_reader :source_document, :text_extraction, :receipt, :extraction_state, :parsing_state

    def broadcast_source_document_status
      broadcast_source_document_replace(
        target: dom_id(source_document, :processing_status),
        partial: "source_documents/processing_status",
        locals: source_document_locals
      )
      broadcast_source_document_replace(
        target: dom_id(source_document, :latest_text_extraction),
        partial: "source_documents/latest_extraction",
        locals: source_document_locals
      )
      broadcast_source_document_replace(
        target: dom_id(source_document, :receipt_summary),
        partial: "source_documents/receipt_summary",
        locals: source_document_locals
      )
    end

    def broadcast_source_document_replace(target:, partial:, locals:)
      Turbo::StreamsChannel.broadcast_replace_to(
        source_document,
        target: target,
        partial: partial,
        locals: locals
      )
    end

    def source_document_locals
      {
        source_document: source_document,
        latest_text_extraction: latest_text_extraction,
        receipt: current_receipt,
        extraction_state: extraction_state,
        parsing_state: parsing_state
      }
    end

    def latest_text_extraction
      text_extraction || source_document.text_extractions.order(ran_at: :desc, created_at: :desc).first
    end

    def current_receipt
      receipt || source_document.receipts.order(created_at: :desc).first
    end

    def broadcast_receipt_lists
      receipt_stream_filters.each do |parser_status|
        Turbo::StreamsChannel.broadcast_replace_to(
          self.class.receipts_stream_name(parser_status),
          target: self.class.receipts_list_dom_id(parser_status),
          partial: "receipts/list",
          locals: { receipts: receipts_for(parser_status), selected_parser_status: parser_status }
        )
      end
    end

    def receipt_stream_filters
      [ nil, *Receipt.parser_statuses.keys ]
    end

    def receipts_for(parser_status)
      receipts = Receipt.includes(store: :retail_brand).recent_first
      return receipts unless parser_status

      receipts.where(parser_status: parser_status)
    end

    def dom_id(record, prefix = nil)
      ActionView::RecordIdentifier.dom_id(record, prefix)
    end
  end
end
