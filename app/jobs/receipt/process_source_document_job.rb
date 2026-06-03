class Receipt::ProcessSourceDocumentJob < ApplicationJob
  queue_as :receipt_handling

  def perform(source_document)
    text_extraction = ReceiptIngestion::ExtractTextService.call(source_document: source_document)
    Receipt::ParseJob.perform_later(text_extraction.id) if text_extraction.success?
  end
end
