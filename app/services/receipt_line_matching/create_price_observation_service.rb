module ReceiptLineMatching
  # Persists the price fact derived from one confirmed receipt-line match.
  class CreatePriceObservationService < ApplicationService
    def initialize(receipt_line_match:)
      @receipt_line_match = receipt_line_match
    end

    def call
      raise ArgumentError unless receipt_line_match.confirmed?

      upsert_price_observation
    end

    private

    attr_reader :receipt_line_match

    def upsert_price_observation
      (receipt_line_match.price_observation || PriceObservation.find_or_initialize_by(receipt_line: receipt_line)).tap do |observation|
        observation.receipt_line_match = receipt_line_match
        observation.receipt_line = receipt_line
        observation.product_variant = product_variant
        observation.store = receipt_line.receipt.store
        observation.observed_at = receipt_line.receipt.purchased_at
        observation.purchased_quantity = receipt_line.quantity
        observation.purchased_unit = receipt_line.unit_of_measure
        observation.total_cents = receipt_line.total_cents
        observation.pack_unit_price_cents = pack_unit_price_cents
        observation.comparison_unit = comparison_unit
        observation.comparison_unit_price_cents = comparison_unit_price_cents
        observation.source = "receipt_line"
        observation.save!
      end
    end

    def receipt_line
      @receipt_line ||= receipt_line_match.receipt_line
    end

    def product_variant
      receipt_line_match.product_variant
    end

    def pack_unit_price_cents
      (receipt_line.total_cents.to_d / receipt_line.quantity).round
    end

    def comparison_unit
      product_variant.comparison_unit if comparison_quantity
    end

    def comparison_unit_price_cents
      return unless comparison_quantity

      (receipt_line.total_cents.to_d / comparison_quantity).round
    end

    def comparison_quantity
      return unless product_variant.comparison_unit && product_variant.quantity_value

      receipt_line.quantity * package_count * product_variant.quantity_value
    end

    def package_count
      product_variant.package_count || 1
    end
  end
end
