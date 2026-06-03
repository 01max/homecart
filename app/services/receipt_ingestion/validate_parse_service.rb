module ReceiptIngestion
  # Recomputes parser validators from persisted receipt records.
  #
  # Validator warnings are replaced with the current result while non-validator
  # warnings, such as parser exceptions and suspected duplicates, remain review
  # blockers.
  class ValidateParseService < ApplicationService
    MONETARY_TOLERANCE_CENTS = Parser::Base::MONETARY_TOLERANCE_CENTS
    VALIDATORS = Parser::Base::VALIDATORS

    Result = Data.define(:receipt, :validator_results)
    ValidatorResult = Data.define(:validator, :passed, :warning)

    # @param receipt [Receipt] persisted receipt whose child records should be checked
    def initialize(receipt:)
      @receipt = receipt
    end

    # @return [Result] receipt plus individual validator results
    def call
      validator_results = [
        validate_totals_sum,
        validate_article_count,
        validate_payments_sum
      ]
      warnings = non_validator_warnings + validator_results.filter_map(&:warning)

      Parser::Base.validate_warnings!(warnings)
      receipt.update!(parser_status: parser_status(validator_results, warnings), parser_warnings: warnings)

      Result.new(receipt: receipt, validator_results: validator_results)
    end

    private

    attr_reader :receipt

    def validate_totals_sum
      discrepancy = receipt.receipt_lines.sum(:total_cents) - receipt.total_cents
      return passed_result(:totals_sum) if discrepancy.abs <= MONETARY_TOLERANCE_CENTS

      failed_result(
        :totals_sum,
        code: "totals_sum_mismatch",
        detail: warning_detail(:totals_sum_mismatch, discrepancy),
        value: discrepancy
      )
    end

    def validate_article_count
      return passed_result(:article_count) if receipt.declared_article_count.nil?

      discrepancy = computed_article_count - receipt.declared_article_count
      return passed_result(:article_count) if discrepancy.zero?

      failed_result(
        :article_count,
        code: "article_count_mismatch",
        detail: warning_detail(:article_count_mismatch, discrepancy),
        value: discrepancy
      )
    end

    def validate_payments_sum
      discrepancy = receipt.receipt_payments.sum(:amount_cents) - receipt.total_cents
      return passed_result(:payments_sum) if discrepancy.abs <= MONETARY_TOLERANCE_CENTS

      failed_result(
        :payments_sum,
        code: "payments_sum_mismatch",
        detail: warning_detail(:payments_sum_mismatch, discrepancy),
        value: discrepancy
      )
    end

    def computed_article_count
      receipt.receipt_lines.sum do |line|
        next 0 unless line.kind == "item"
        next line.quantity.to_i if line.unit_of_measure == "piece"

        1
      end
    end

    def passed_result(validator)
      ValidatorResult.new(validator: VALIDATORS.fetch(validator), passed: true, warning: nil)
    end

    def failed_result(validator, code:, detail:, value:)
      warning = {
        code: code,
        validator: VALIDATORS.fetch(validator),
        detail: detail,
        value: value
      }
      Parser::Base.validate_warning!(warning)

      ValidatorResult.new(validator: VALIDATORS.fetch(validator), passed: false, warning: warning)
    end

    def warning_detail(key, discrepancy)
      I18n.t(
        "receipt_ingestion.parser_warnings.#{key}.detail",
        count: discrepancy.abs,
        discrepancy: discrepancy
      )
    end

    def non_validator_warnings
      receipt.parser_warnings.filter_map do |warning|
        normalized_warning = warning.to_h.symbolize_keys
        next if VALIDATORS.values.include?(normalized_warning[:validator])

        normalized_warning
      end
    end

    def parser_status(validator_results, warnings)
      validator_results.all?(&:passed) && warnings.empty? ? "parsed" : "needs_review"
    end
  end
end
