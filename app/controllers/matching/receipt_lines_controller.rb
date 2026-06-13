module Matching
  # Handles one-line matching decisions from the matching queue.
  class ReceiptLinesController < ApplicationController
    before_action :load_receipt_line
    before_action :load_product_variant

    def confirm
      ReceiptLineMatching::ConfirmMatchService.call(receipt_line: @receipt_line, product_variant: @product_variant)

      redirect_to matching_queue_path,
                  notice: t("matching.receipt_lines.confirm.success", label: @receipt_line.label)
    end

    def reject
      ReceiptLineMatching::RejectMatchService.call(receipt_line: @receipt_line, product_variant: @product_variant)

      redirect_to matching_queue_path,
                  notice: t("matching.receipt_lines.reject.success", label: @receipt_line.label)
    end

    private

    def load_receipt_line
      @receipt_line = ReceiptLine.find(params[:id])
    end

    def load_product_variant
      @product_variant = ProductVariant.find(params.require(:product_variant_id))
    end
  end
end
