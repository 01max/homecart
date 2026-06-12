module ReceiptLineMatching
  # Confirms one receipt line against a product variant and records its price fact.
  class ConfirmMatchService < ApplicationService
    Result = Data.define(:receipt_line_match, :price_observation)

    def initialize(receipt_line:, product_variant:, source: "user", decided_at: Time.current)
      @receipt_line = receipt_line
      @product_variant = product_variant
      @source = source
      @decided_at = decided_at
    end

    def call
      ApplicationRecord.transaction do
        receipt_line.with_lock do
          match = confirmed_match
          price_observation = upsert_price_observation(match)

          Result.new(receipt_line_match: match, price_observation: price_observation)
        end
      end
    end

    private

    attr_reader :receipt_line, :product_variant, :source, :decided_at

    def confirmed_match
      (terminal_match || suggested_match || receipt_line.receipt_line_matches.build).tap do |match|
        match.product_variant = product_variant
        match.status = "confirmed"
        match.source = source.to_s
        match.confidence = nil
        match.label_snapshot = receipt_line.label
        match.decided_at = decided_at
        match.save!
      end
    end

    def terminal_match
      ReceiptLineMatch.terminal_decisions.where(receipt_line: receipt_line).first
    end

    def suggested_match
      receipt_line.receipt_line_matches.suggested.find_by(product_variant: product_variant)
    end

    def upsert_price_observation(match)
      (match.price_observation || PriceObservation.find_or_initialize_by(receipt_line: receipt_line)).tap do |observation|
        observation.receipt_line_match = match
        observation.receipt_line = receipt_line
        observation.product_variant = product_variant
        observation.store = receipt_line.receipt.store
        observation.observed_at = receipt_line.receipt.purchased_at
        observation.purchased_quantity = receipt_line.quantity
        observation.purchased_unit = receipt_line.unit_of_measure
        observation.total_cents = receipt_line.total_cents
        observation.pack_unit_price_cents = pack_unit_price_cents
        observation.comparison_unit = nil
        observation.comparison_unit_price_cents = nil
        observation.source = "receipt_line"
        observation.save!
      end
    end

    def pack_unit_price_cents
      (receipt_line.total_cents.to_d / receipt_line.quantity).round
    end
  end
end
