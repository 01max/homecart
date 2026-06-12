module ReceiptLineMatching
  # Records that a receipt line should not be matched to a catalogue variant.
  class IgnoreLineService < ApplicationService
    def initialize(receipt_line:, source: "user", decided_at: Time.current)
      @receipt_line = receipt_line
      @source = source
      @decided_at = decided_at
    end

    def call
      ApplicationRecord.transaction do
        receipt_line.with_lock do
          remove_price_observation
          ignored_match.tap(&:save!)
        end
      end
    end

    private

    attr_reader :receipt_line, :source, :decided_at

    def ignored_match
      (terminal_match || receipt_line.receipt_line_matches.build).tap do |match|
        match.product_variant = nil
        match.status = "ignored"
        match.source = source.to_s
        match.confidence = nil
        match.label_snapshot = receipt_line.label
        match.decided_at = decided_at
      end
    end

    def terminal_match
      ReceiptLineMatch.terminal_decisions.where(receipt_line: receipt_line).first
    end

    def remove_price_observation
      PriceObservation.find_by(receipt_line: receipt_line)&.destroy!
    end
  end
end
