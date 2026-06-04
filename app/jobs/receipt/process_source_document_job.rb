# Runs the asynchronous source-document processing pipeline.
#
# This job extracts text from an uploaded source document and enqueues parsing
# only when extraction succeeds. Extraction failure details are persisted by
# {ReceiptIngestion::ExtractTextService}.
class Receipt::ProcessSourceDocumentJob < ApplicationJob
  queue_as :receipt_handling

  # @param source_document [SourceDocument] uploaded receipt source document
  # @param broadcaster [Class] service that broadcasts UI pipeline state
  # @return [void]
  def perform(source_document, broadcaster: ReceiptIngestion::BroadcastProcessingStatusService)
    broadcaster.call(source_document: source_document, extraction_state: "running", parsing_state: "waiting")

    text_extraction = ReceiptIngestion::ExtractTextService.call(source_document: source_document)
    if text_extraction.success?
      Receipt::ParseJob.perform_later(text_extraction.id)
      broadcaster.call(
        source_document: source_document,
        text_extraction: text_extraction,
        extraction_state: "complete",
        parsing_state: "queued"
      )
    else
      broadcaster.call(
        source_document: source_document,
        text_extraction: text_extraction,
        extraction_state: "failed",
        parsing_state: "blocked"
      )
    end
  rescue StandardError
    broadcaster.call(source_document: source_document, extraction_state: "failed", parsing_state: "blocked")
    raise
  end
end
