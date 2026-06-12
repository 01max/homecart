module ReceiptLineMatching
  # Records that a suggested variant is wrong for one receipt line.
  class RejectMatchService < ApplicationService
    def initialize(receipt_line:, product_variant:, source: "user", decided_at: Time.current)
      @receipt_line = receipt_line
      @product_variant = product_variant
      @source = source
      @decided_at = decided_at
    end

    def call
      receipt_line.with_lock do
        rejected_match.tap(&:save!)
      end
    end

    private

    attr_reader :receipt_line, :product_variant, :source, :decided_at

    def rejected_match
      (suggested_match || existing_rejection || receipt_line.receipt_line_matches.build).tap do |match|
        match.product_variant = product_variant
        match.status = "rejected"
        match.source = source.to_s
        match.confidence = nil
        match.label_snapshot = receipt_line.label
        match.decided_at = decided_at
      end
    end

    def suggested_match
      receipt_line.receipt_line_matches.suggested.find_by(product_variant: product_variant)
    end

    def existing_rejection
      receipt_line.receipt_line_matches.rejected.find_by(product_variant: product_variant)
    end
  end
end
