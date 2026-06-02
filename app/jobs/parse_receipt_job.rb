class ParseReceiptJob < ApplicationJob
  queue_as :receipt_handling

  discard_on ActiveRecord::RecordNotFound

  def perform(text_extraction_id)
    text_extraction = TextExtraction.find(text_extraction_id)
    return unless text_extraction.success?

    ReceiptIngestion::ParseService.call(text_extraction: text_extraction)
  end
end
