module ReceiptLineMatching
  # Confirms all currently eligible lines in one normalized-label group.
  class BulkConfirmService < ApplicationService
    Preview = Data.define(:normalized_label, :representative_label, :affected_count, :receipt_lines)
    Result = Data.define(:preview, :confirmations)

    def self.preview(...)
      new(...).preview
    end

    def initialize(normalized_label:, product_variant: nil, expected_count: nil, scope: ReceiptLine.all, decided_at: Time.current)
      @normalized_label = ProductCatalog::NormalizeTextService.call(normalized_label)
      @product_variant = product_variant
      @expected_count = expected_count
      @scope = scope
      @decided_at = decided_at
    end

    def call
      current_preview = preview
      ensure_expected_count!(current_preview)

      ApplicationRecord.transaction do
        confirmations = current_preview.receipt_lines.map do |receipt_line|
          ConfirmMatchService.call(receipt_line: receipt_line, product_variant: product_variant, decided_at: decided_at)
        end

        Result.new(preview: current_preview, confirmations: confirmations)
      end
    end

    def preview
      lines = eligible_lines

      Preview.new(
        normalized_label: normalized_label,
        representative_label: representative_label(lines),
        affected_count: lines.size,
        receipt_lines: lines
      )
    end

    private

    attr_reader :normalized_label, :product_variant, :expected_count, :scope, :decided_at

    def eligible_lines
      QueueService.call(scope: scope)
        .find { |group| group.normalized_label == normalized_label }
        &.receipt_lines || []
    end

    def representative_label(lines)
      lines.first&.label
    end

    def ensure_expected_count!(current_preview)
      return if expected_count.to_i == current_preview.affected_count

      raise ArgumentError
    end
  end
end
