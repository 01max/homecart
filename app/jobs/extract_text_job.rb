class ExtractTextJob < ApplicationJob
  queue_as :receipt_handling

  def perform(source_document)
    ReceiptIngestion::ExtractTextService.call(source_document: source_document)
  end
end
