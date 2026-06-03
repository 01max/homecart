# Runs asynchronous parsing for a successful text extraction.
#
# The job intentionally stays orchestration-thin: it loads the extraction,
# checks that extraction succeeded, and delegates parser persistence to
# {ReceiptIngestion::ParseService}.
class Receipt::ParseJob < ApplicationJob
  queue_as :receipt_handling

  discard_on ActiveRecord::RecordNotFound

  # @param text_extraction_id [String] UUID of the extraction to parse
  # @param broadcaster [Class] service that broadcasts UI pipeline state
  # @return [void]
  def perform(text_extraction_id, broadcaster: ReceiptIngestion::BroadcastProcessingStatusService)
    text_extraction = TextExtraction.find(text_extraction_id)
    return unless text_extraction.success?

    source_document = text_extraction.source_document
    broadcaster.call(
      source_document: source_document,
      text_extraction: text_extraction,
      extraction_state: "complete",
      parsing_state: "running"
    )

    result = ReceiptIngestion::ParseService.call(text_extraction: text_extraction)
    broadcaster.call(
      source_document: source_document,
      text_extraction: text_extraction,
      receipt: result.receipt,
      extraction_state: "complete",
      parsing_state: "complete"
    )
  rescue StandardError
    broadcaster.call(
      source_document: source_document,
      text_extraction: text_extraction,
      extraction_state: "complete",
      parsing_state: "failed"
    ) if defined?(source_document) && source_document
    raise
  end
end
