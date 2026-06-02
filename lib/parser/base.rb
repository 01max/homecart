require "bigdecimal"

module Parser
  class Base
    MONETARY_TOLERANCE_CENTS = 1
    VALIDATORS = {
      totals_sum: "validate_totals_sum",
      article_count: "validate_article_count",
      payments_sum: "validate_payments_sum"
    }.freeze

    Result = Data.define(:receipt, :lines, :promotions, :payments, :warnings)

    WarningShapeError = Class.new(ArgumentError)

    class << self
      def validate_warnings!(warnings)
        raise WarningShapeError, "warnings must be an array" unless warnings.is_a?(Array)

        warnings.each { |warning| validate_warning!(warning) }
      end

      def validate_warning!(warning)
        unless warning.is_a?(Hash)
          raise WarningShapeError, "warning must be a hash with code, validator, detail, and value"
        end

        extra_keys = warning.keys - warning_keys
        missing_keys = warning_keys - warning.keys
        raise WarningShapeError, "warning has unsupported keys: #{extra_keys.join(', ')}" if extra_keys.any?
        raise WarningShapeError, "warning is missing keys: #{missing_keys.join(', ')}" if missing_keys.any?
        raise WarningShapeError, "warning code must be a string" unless warning[:code].is_a?(String)

        unless warning[:validator].nil? || warning[:validator].is_a?(String)
          raise WarningShapeError, "warning validator must be a string or nil"
        end

        raise WarningShapeError, "warning detail must be a string" unless warning[:detail].is_a?(String)

        return if warning[:value].nil? || warning[:value].is_a?(Numeric)

        raise WarningShapeError, "warning value must be numeric or nil"
      end

      private

      def warning_keys
        @warning_keys ||= %i[ code validator detail value ].freeze
      end
    end

    attr_reader :text, :warnings

    def initialize(text:)
      @text = text
      @warnings = []
    end

    def call
      raise NotImplementedError, "#{self.class.name} must implement #call"
    end

    private

    def result_envelope(receipt:, lines:, promotions: [], payments:, warnings: self.warnings)
      self.class.validate_warnings!(warnings)

      Result.new(
        receipt: receipt,
        lines: lines,
        promotions: promotions,
        payments: payments,
        warnings: warnings
      )
    end

    def validate_totals_sum(result)
      declared_total_cents = integer_attribute(result.receipt, :total_cents)
      computed_total_cents = result.lines.sum { |line| integer_attribute(line, :total_cents) || 0 }
      discrepancy = computed_total_cents - declared_total_cents
      return true if discrepancy.abs <= MONETARY_TOLERANCE_CENTS

      add_warning(
        code: "totals_sum_mismatch",
        validator: VALIDATORS.fetch(:totals_sum),
        detail: "Line totals differ from receipt total by #{discrepancy} cents",
        value: discrepancy
      )

      false
    end

    def validate_article_count(result)
      declared_article_count = integer_attribute(result.receipt, :declared_article_count)
      return true if declared_article_count.nil?

      computed_article_count = result.lines.sum { |line| article_count_for(line) }
      discrepancy = computed_article_count - declared_article_count
      return true if discrepancy.zero?

      add_warning(
        code: "article_count_mismatch",
        validator: VALIDATORS.fetch(:article_count),
        detail: "Article count differs from declared count by #{discrepancy}",
        value: discrepancy
      )

      false
    end

    def validate_payments_sum(result)
      declared_total_cents = integer_attribute(result.receipt, :total_cents)
      computed_payment_cents = result.payments.sum { |payment| integer_attribute(payment, :amount_cents) || 0 }
      discrepancy = computed_payment_cents - declared_total_cents
      return true if discrepancy.abs <= MONETARY_TOLERANCE_CENTS

      add_warning(
        code: "payments_sum_mismatch",
        validator: VALIDATORS.fetch(:payments_sum),
        detail: "Payment sum differs from receipt total by #{discrepancy} cents",
        value: discrepancy
      )

      false
    end

    def add_warning(code:, detail:, validator: nil, value: nil)
      warning = {
        code: code,
        validator: validator,
        detail: detail,
        value: value
      }
      self.class.validate_warning!(warning)

      warnings << warning
      warning
    end

    def integer_attribute(record, attribute)
      value = attribute_value(record, attribute)
      return if value.nil?

      value.to_i
    end

    def decimal_attribute(record, attribute)
      value = attribute_value(record, attribute)
      return if value.nil?

      BigDecimal(value.to_s)
    end

    def cents_from(amount)
      return unless amount

      sign = amount.start_with?("-") ? -1 : 1
      euros, cents = amount.delete_prefix("-").split(/[,.]/)
      sign * ((euros.to_i * 100) + cents.to_i)
    end

    def decimal_from(value)
      return unless value

      BigDecimal(value.tr(",", "."))
    end

    def french_month_number(month)
      Parser::FrenchDates.month_number(month)
    end

    def text_lines
      @text_lines ||= text.lines.map(&:strip).reject(&:blank?)
    end

    def attribute_value(record, attribute)
      return record.fetch(attribute) if record.is_a?(Hash) && record.key?(attribute)
      return record.fetch(attribute.to_s) if record.is_a?(Hash) && record.key?(attribute.to_s)

      record.public_send(attribute)
    end

    def article_count_for(line)
      return 0 unless attribute_value(line, :kind).to_s == "item"

      unit_of_measure = attribute_value(line, :unit_of_measure).to_s
      return decimal_attribute(line, :quantity).to_i if unit_of_measure == "piece"

      1
    end
  end
end
