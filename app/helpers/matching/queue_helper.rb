module Matching
  module QueueHelper
    def matching_queue_date_range(group)
      return t("matching.workflow.empty_value") if group.first_purchased_at.blank? && group.last_purchased_at.blank?

      first_date = matching_queue_date_label(group.first_purchased_at)
      last_date = matching_queue_date_label(group.last_purchased_at)

      return first_date if first_date == last_date

      t("matching.workflow.date_range", first: first_date, last: last_date)
    end

    def matching_queue_store_list(stores)
      stores.map { |store| store_label(store) }.to_sentence
    end

    def matching_queue_price_context(price_context)
      [
        matching_queue_money_values("matching.workflow.price_context.total", price_context.total_cents),
        matching_queue_money_values("matching.workflow.price_context.unit", price_context.unit_price_cents)
      ].compact.to_sentence.presence || t("matching.workflow.empty_value")
    end

    def matching_queue_quantity_context(price_context)
      quantities = price_context.quantities.map { |quantity| matching_queue_decimal_label(quantity) }
      units = price_context.units.map { |unit| t("receipts.unit_of_measures.#{unit}") }

      [
        matching_queue_values("matching.workflow.quantity_context.quantities", quantities),
        matching_queue_values("matching.workflow.quantity_context.units", units)
      ].compact.to_sentence.presence || t("matching.workflow.empty_value")
    end

    def matching_queue_suggestion_reason(reason)
      t("matching.workflow.suggestions.reasons.#{reason}")
    end

    def matching_queue_confidence_label(confidence)
      return t("matching.workflow.empty_value") if confidence.blank?

      number_to_percentage(confidence * 100, precision: 0)
    end

    def matching_queue_money_label(cents)
      number_to_currency(cents / 100.0, unit: "€", separator: ",", delimiter: " ", format: "%n %u")
    end

    def matching_queue_date_label(value)
      return t("matching.workflow.empty_value") if value.blank?

      l(value.to_date, format: :short)
    end

    def matching_queue_quantity_value(line)
      matching_queue_decimal_label(line.quantity)
    end

    private

    def matching_queue_money_values(key, values)
      matching_queue_values(key, values.map { |value| matching_queue_money_label(value) })
    end

    def matching_queue_values(key, values)
      return if values.blank?

      t(key, values: values.to_sentence)
    end

    def matching_queue_decimal_label(value)
      number_with_precision(value, strip_insignificant_zeros: true)
    end
  end
end
