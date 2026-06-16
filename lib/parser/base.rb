require "bigdecimal"

module Parser
  # Base contract for all receipt parsers.
  #
  # Concrete parser classes provide receipt attributes, parsed lines, and
  # payments. Base assembles the result envelope, runs shared validators, and
  # enforces structured parser warnings.
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
      # Validate a parser warning array before it is persisted.
      #
      # @param warnings [Array<Hash>] warning hashes shaped for `Receipt#parser_warnings`
      # @return [Array<Hash>] the validated warnings
      # @raise [WarningShapeError] when any warning is malformed
      def validate_warnings!(warnings)
        raise WarningShapeError, "warnings must be an array" unless warnings.is_a?(Array)

        warnings.each { |warning| validate_warning!(warning) }
      end

      # Validate one structured parser warning.
      #
      # @param warning [Hash] warning with `:code`, `:validator`, `:detail`, and `:value`
      # @return [void]
      # @raise [WarningShapeError] when required keys or value types are invalid
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

    # @param text [String] extracted receipt text to parse
    def initialize(text:)
      @text = text
      @warnings = []
    end

    # Build a parser result and run shared validators.
    #
    # @return [Result] parser result envelope for persistence
    def call
      result = result_envelope(
        receipt: receipt_attributes,
        lines: line_attributes,
        promotions: promotion_attributes,
        payments: payment_attributes
      )
      after_parse(result)
      validator_results = [
        validate_totals_sum(result),
        validate_article_count(result),
        validate_payments_sum(result)
      ]
      result.receipt[:parser_status] = parser_status(result, validator_results)

      result
    end

    private

    # @!method receipt_attributes
    #   Receipt-level attributes returned by the concrete parser.
    #   @return [Hash]
    def receipt_attributes
      raise NotImplementedError, "#{self.class.name} must implement #receipt_attributes"
    end

    # Assign receipt-order positions to parsed line attributes.
    #
    # @return [Array<Hash>] line attributes with `:position` populated
    def line_attributes
      @line_attributes ||= coalesced_duplicate_item_lines.map.with_index(1) { |line, position| line.merge(position: position) }
    end

    # @!method parsed_lines
    #   Parsed line attributes before Base assigns positions.
    #   @return [Array<Hash>]
    def parsed_lines
      raise NotImplementedError, "#{self.class.name} must implement #parsed_lines or #line_attributes"
    end

    def coalesced_duplicate_item_lines
      duplicate_line_runs.map do |run|
        line = run.fetch(:line)
        line[:unit_price_cents] ||= inferred_unit_price_cents(line) if run.fetch(:count) > 1
        line
      end
    end

    def duplicate_line_runs
      parsed_lines.each_with_object([]) do |line, runs|
        current_key = duplicate_item_line_key(line)
        previous_run = runs.last

        if current_key && previous_run&.fetch(:key) == current_key
          merge_duplicate_item_line(previous_run.fetch(:line), line)
          previous_run[:count] += 1
        else
          runs << { line: line.dup, key: current_key, count: 1 }
        end
      end
    end

    def merge_duplicate_item_line(target, source)
      target[:quantity] = decimal_line_value(target, :quantity) + decimal_line_value(source, :quantity)
      target[:total_cents] = integer_line_value(target, :total_cents) + integer_line_value(source, :total_cents)
    end

    def duplicate_item_line_key(line)
      return unless line_value(line, :kind).to_s == "item"
      return unless line_value(line, :unit_of_measure).to_s == "piece"
      return if line_value(line, :raw_text).blank?
      return if line_value(line, :label).blank?
      return if line_value(line, :quantity).nil?
      return if line_value(line, :total_cents).nil?

      %i[
        raw_text
        label
        label_truncated
        unit_of_measure
        unit_price_cents
        vat_rate_bp
        tr_eligible
        section_label
        kind
      ].map { |attribute| line_value(line, attribute) }
    end

    def inferred_unit_price_cents(line)
      quantity = decimal_line_value(line, :quantity)
      return if quantity.zero?

      unit_price = BigDecimal(integer_line_value(line, :total_cents).to_s) / quantity
      unit_price.to_i if unit_price == unit_price.to_i
    end

    # @return [Array<Hash>] parsed promotion attributes, if any
    def promotion_attributes
      []
    end

    # @!method payment_attributes
    #   Parsed payment attributes for the receipt.
    #   @return [Array<Hash>]
    def payment_attributes
      raise NotImplementedError, "#{self.class.name} must implement #payment_attributes"
    end

    def payment_category(raw_label)
      case raw_label
      when /\ACB Web\b/i
        "web"
      when /\ACB\s*\(T\s*restau\)/i, /\ACB TRD\b/i
        "tickets_restaurant"
      when /\A(?:CB|CARTE BANCAIRE)\b/i
        "bank_card"
      when /\A(?:ESPECES|ESP[EÈ]CES)\b/i
        "cash"
      else
        "other"
      end
    end

    def after_parse(_result) = nil

    def parser_status(_result, validator_results)
      validator_results.all? && blocking_warnings.empty? ? "parsed" : "needs_review"
    end

    def blocking_warnings
      warnings
    end

    # Build the immutable parser result envelope consumed by ParseService.
    #
    # @param receipt [Hash] receipt attributes
    # @param lines [Array<Hash>] line attributes
    # @param promotions [Array<Hash>] promotion attributes
    # @param payments [Array<Hash>] payment attributes
    # @param warnings [Array<Hash>] structured parser warnings
    # @return [Result]
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

    # Validate that line totals reconcile with the receipt total.
    #
    # @param result [Result] parser result envelope
    # @return [Boolean] true when the validator passes within the monetary tolerance
    def validate_totals_sum(result)
      declared_total_cents = integer_attribute(result.receipt, :total_cents)
      computed_total_cents = result.lines.sum { |line| integer_attribute(line, :total_cents) || 0 }
      discrepancy = computed_total_cents - declared_total_cents
      return true if discrepancy.abs <= MONETARY_TOLERANCE_CENTS

      add_warning(
        code: "totals_sum_mismatch",
        validator: VALIDATORS.fetch(:totals_sum),
        detail: validator_warning_detail(:totals_sum_mismatch, discrepancy),
        value: discrepancy
      )

      false
    end

    # Validate declared article count when the source provides one.
    #
    # @param result [Result] parser result envelope
    # @return [Boolean] true when skipped or when item quantities reconcile
    def validate_article_count(result)
      declared_article_count = integer_attribute(result.receipt, :declared_article_count)
      return true if declared_article_count.nil?

      computed_article_count = result.lines.sum { |line| article_count_for(line) }
      discrepancy = computed_article_count - declared_article_count
      return true if discrepancy.zero?

      add_warning(
        code: "article_count_mismatch",
        validator: VALIDATORS.fetch(:article_count),
        detail: validator_warning_detail(:article_count_mismatch, discrepancy),
        value: discrepancy
      )

      false
    end

    # Validate that payment rows reconcile with the receipt total.
    #
    # @param result [Result] parser result envelope
    # @return [Boolean] true when the validator passes within the monetary tolerance
    def validate_payments_sum(result)
      declared_total_cents = integer_attribute(result.receipt, :total_cents)
      computed_payment_cents = result.payments.sum { |payment| integer_attribute(payment, :amount_cents) || 0 }
      discrepancy = computed_payment_cents - declared_total_cents
      return true if discrepancy.abs <= MONETARY_TOLERANCE_CENTS

      add_warning(
        code: "payments_sum_mismatch",
        validator: VALIDATORS.fetch(:payments_sum),
        detail: validator_warning_detail(:payments_sum_mismatch, discrepancy),
        value: discrepancy
      )

      false
    end

    # Append a structured parser warning.
    #
    # @param code [String] stable machine-readable warning code
    # @param detail [String] translated human-readable review detail
    # @param validator [String, nil] validator method name, or nil for non-validator warnings
    # @param value [Numeric, nil] discrepancy or other numeric value
    # @return [Hash] appended warning
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

    def validator_warning_detail(key, discrepancy)
      I18n.t(
        "receipt_ingestion.parser_warnings.#{key}.detail",
        count: discrepancy.abs,
        discrepancy: discrepancy
      )
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

    def normalize_label(label)
      label.sub(/\s*\.\.\z/, "").strip
    end

    def label_truncated?(label)
      label.match?(/\s*\.\.\z/)
    end

    def promotion_attributes_for(program:, unit:, delta:, label:, kind:, linked_line_position: nil)
      {
        program: program,
        unit: unit,
        delta: delta,
        label: normalize_label(label),
        kind: kind,
        linked_line_position: linked_line_position,
        linking_method: linked_line_position ? "parser_inferred" : "unallocated"
      }
    end

    def linked_line_position_for(label)
      normalized_label = comparable_label(label)
      return if normalized_label.blank?

      line_attributes.find do |line|
        line_label = comparable_label(line.fetch(:label))
        next false if line_label.blank?

        normalized_label.start_with?(line_label) || line_label.start_with?(normalized_label)
      end&.fetch(:position)
    end

    def comparable_label(label)
      normalize_label(label.to_s).upcase.gsub(/\s+/, " ").strip
    end

    def integer_line_value(line, attribute)
      line_value(line, attribute).to_i
    end

    def decimal_line_value(line, attribute)
      BigDecimal(line_value(line, attribute).to_s)
    end

    def line_value(line, attribute)
      return line[attribute] if line.key?(attribute)

      line[attribute.to_s] if line.key?(attribute.to_s)
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
