# Runs the asynchronous source-document processing pipeline.
#
# This job extracts text from an uploaded source document and enqueues parsing
# only when extraction succeeds. Extraction failure details are persisted by
# {ReceiptIngestion::ExtractTextService}.
class Receipt::ProcessSourceDocumentJob < ApplicationJob
  queue_as :receipt_handling

  # @param source_document [SourceDocument] uploaded receipt source document
  # @return [void]
  def perform(source_document)
    text_extraction = ReceiptIngestion::ExtractTextService.call(source_document: source_document)
    Receipt::ParseJob.perform_later(text_extraction.id) if text_extraction.success?
  end
end
