# Runs the asynchronous source-document processing pipeline.
#
# This job extracts text from an uploaded source document, runs source
# detection, and enqueues parsing only when extraction and classification
# succeed. Extraction failure details are persisted by
# {ReceiptIngestion::ExtractTextService}.
class Receipt::ProcessSourceDocumentJob < ApplicationJob
  queue_as :receipt_handling

  # @param source_document [SourceDocument] uploaded receipt source document
  # @param broadcaster [Class] service that broadcasts UI pipeline state
  # @param source_detector [Class] service that classifies extracted source text
  # @param parse_job_class [Class] job class used to continue parsing
  # @return [void]
  def perform(
    source_document,
    broadcaster: ReceiptIngestion::BroadcastProcessingStatusService,
    source_detector: ReceiptIngestion::DetectSourceDocumentService,
    parse_job_class: Receipt::ParseJob
  )
    broadcaster.call(source_document: source_document, extraction_state: "running", parsing_state: "waiting")

    text_extraction = ReceiptIngestion::ExtractTextService.call(source_document: source_document)
    if text_extraction.success?
      detection_result = source_detector.call(text_extraction: text_extraction)
      source_document = detection_result.source_document
      parsing_state = detection_result.classified? ? "queued" : "blocked"
      parse_job_class.perform_later(text_extraction.id) if detection_result.classified?

      broadcaster.call(
        source_document: source_document,
        text_extraction: text_extraction,
        extraction_state: "complete",
        parsing_state: parsing_state
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
