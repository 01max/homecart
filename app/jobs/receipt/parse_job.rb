# Runs asynchronous parsing for a successful text extraction.
#
# The job intentionally stays orchestration-thin: it loads the extraction,
# checks that extraction succeeded, and delegates parser persistence to
# {ReceiptIngestion::ParseService}.
class Receipt::ParseJob < ApplicationJob
  queue_as :receipt_handling

  discard_on ActiveRecord::RecordNotFound

  # @param text_extraction_id [String] UUID of the extraction to parse
  # @return [void]
  def perform(text_extraction_id)
    text_extraction = TextExtraction.find(text_extraction_id)
    return unless text_extraction.success?

    ReceiptIngestion::ParseService.call(text_extraction: text_extraction)
  end
end
