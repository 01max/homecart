module ReceiptLineMatching
  # Builds the receipt-scoped matching queue with suggestions for each item line.
  class ReceiptQueueService < ApplicationService
    Entry = Data.define(:receipt_line, :suggestions)

    def initialize(
      receipt:,
      suggestion_limit: SuggestMatchesService::DEFAULT_LIMIT,
      persist_suggestions: true
    )
      @receipt = receipt
      @suggestion_limit = suggestion_limit
      @persist_suggestions = persist_suggestions
    end

    def call
      unmatched_item_lines.map do |receipt_line|
        Entry.new(
          receipt_line: receipt_line,
          suggestions: suggestions_for(receipt_line)
        )
      end
    end

    private

    attr_reader :receipt, :suggestion_limit, :persist_suggestions

    def unmatched_item_lines
      receipt.receipt_lines
        .kind_item
        .where.not(id: ReceiptLineMatch.terminal_decisions.select(:receipt_line_id))
        .order(:position, :id)
    end

    def suggestions_for(receipt_line)
      SuggestMatchesService.call(
        receipt_line: receipt_line,
        limit: suggestion_limit,
        persist: persist_suggestions
      )
    end
  end
end
