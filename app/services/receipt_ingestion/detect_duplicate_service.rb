module ReceiptIngestion
  # Checks a parsed receipt candidate against existing persisted receipts.
  #
  # Exact composite duplicates are rejected. Softer same-store/same-day/same-total
  # matches are preserved as structured parser warnings so review can decide.
  class DetectDuplicateService < ApplicationService
    Result = Data.define(:receipt, :suspected_duplicate)

    DuplicateReceiptError = Class.new(StandardError)

    SUSPECTED_DUPLICATE_CODE = "suspected_duplicate"

    # @param receipt [Receipt] unsaved or persisted receipt candidate
    def initialize(receipt:)
      @receipt = receipt
    end

    # @return [Result] receipt plus the suspected duplicate, when present
    # @raise [DuplicateReceiptError] when a strict composite duplicate exists
    def call
      raise DuplicateReceiptError, duplicate_error_detail(strict_duplicate) if strict_duplicate

      if suspected_duplicate
        receipt.parser_warnings = non_suspected_duplicate_warnings + [ suspected_duplicate_warning(suspected_duplicate) ]
      end

      Result.new(receipt: receipt, suspected_duplicate: suspected_duplicate)
    end

    private

    attr_reader :receipt

    def strict_duplicate
      return unless strict_duplicate_attributes_present?

      @strict_duplicate ||= comparable_receipts.find_by(
        store: receipt.store,
        register_number: receipt.register_number,
        ticket_number: receipt.ticket_number,
        purchased_at: receipt.purchased_at
      )
    end

    def suspected_duplicate
      return unless suspected_duplicate_attributes_present?

      @suspected_duplicate ||= comparable_receipts
        .where(store: receipt.store, total_cents: receipt.total_cents)
        .where(purchased_at: receipt.purchased_at.all_day)
        .recent_first
        .first
    end

    def comparable_receipts
      scope = Receipt.all
      scope = scope.where.not(id: receipt.id) if receipt.persisted?
      scope
    end

    def strict_duplicate_attributes_present?
      receipt.store.present? &&
        receipt.register_number.present? &&
        receipt.ticket_number.present? &&
        receipt.purchased_at.present?
    end

    def suspected_duplicate_attributes_present?
      receipt.store.present? && receipt.purchased_at.present? && receipt.total_cents.present?
    end

    def suspected_duplicate_warning(duplicate)
      warning = {
        code: SUSPECTED_DUPLICATE_CODE,
        validator: nil,
        detail: I18n.t("receipt_ingestion.detect_duplicate.warnings.suspected_duplicate.detail", receipt_id: duplicate.id),
        value: nil
      }
      Parser::Base.validate_warning!(warning)

      warning
    end

    def non_suspected_duplicate_warnings
      receipt.parser_warnings.filter_map do |warning|
        normalized_warning = warning.to_h.symbolize_keys
        next if normalized_warning[:code] == SUSPECTED_DUPLICATE_CODE

        normalized_warning
      end
    end

    def duplicate_error_detail(duplicate)
      I18n.t("receipt_ingestion.detect_duplicate.errors.duplicate_receipt", receipt_id: duplicate.id)
    end
  end
end
