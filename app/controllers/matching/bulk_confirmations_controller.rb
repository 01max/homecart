module Matching
  # Applies explicit bulk confirmations after a count preview.
  class BulkConfirmationsController < ApplicationController
    def create
      result = ReceiptLineMatching::BulkConfirmService.call(
        normalized_label: bulk_confirmation_params[:normalized_label],
        product_variant: product_variant,
        expected_receipt_line_ids: bulk_confirmation_params[:receipt_line_ids]
      )

      redirect_to decision_redirect_path,
                  notice: t(
                    "matching.bulk_confirmations.create.success",
                    count: result.confirmations.size,
                    label: result.preview.representative_label
                  )
    rescue ArgumentError
      redirect_to decision_redirect_path, alert: t("matching.bulk_confirmations.create.errors.stale_preview")
    end

    private

    def bulk_confirmation_params
      params.require(:bulk_confirmation).permit(:normalized_label, :product_variant_id, receipt_line_ids: [])
    end

    def product_variant
      ProductVariant.find(bulk_confirmation_params[:product_variant_id])
    end

    def decision_redirect_path
      url_from(params[:return_to]) || matching_queue_path
    end
  end
end
