module ReceiptIngestion
  # Finalizes a human-reviewed receipt after persisted validators pass.
  #
  # The service recomputes the same server-side validators used after parsing,
  # confirms promotion link provenance, then transitions the receipt to reviewed.
  class FinalizeReviewService < ApplicationService
    Result = Data.define(:receipt, :validator_results) do
      # @return [Boolean] true when every persisted validator passes
      def success?
        validator_results.all?(&:passed)
      end

      # @return [Array<String>] validator method names that failed
      def failed_validators
        validator_results.reject(&:passed).map(&:validator)
      end
    end

    # @param receipt [Receipt] persisted receipt to finalize
    def initialize(receipt:)
      @receipt = receipt
    end

    # @return [Result] finalization result and individual validator outcomes
    def call
      result = nil

      Receipt.transaction do
        validation_result = ValidateParseService.call(receipt: receipt)
        result = Result.new(receipt: receipt, validator_results: validation_result.validator_results)

        if result.success?
          confirm_promotion_links
          receipt.update!(parser_status: "reviewed")
        end
      end

      result
    end

    private

    attr_reader :receipt

    def confirm_promotion_links
      receipt.receipt_promotions.reload.find_each do |promotion|
        promotion.update!(linking_method: promotion.linked_line_id.present? ? "user_confirmed" : "unallocated")
      end
    end
  end
end
