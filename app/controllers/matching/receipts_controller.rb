module Matching
  # Entry point for matching a single reviewed receipt.
  class ReceiptsController < ApplicationController
    def show
      @receipt = Receipt.includes(:receipt_lines, store: :retail_brand).find(params[:id])
      return redirect_to receipt_path(@receipt), alert: t(".errors.receipt_not_reviewed") unless @receipt.reviewed?
      return redirect_to receipt_path(@receipt), alert: t(".errors.purchase_date_required") if @receipt.purchased_at.blank?

      @entries = ReceiptLineMatching::ReceiptQueueService.call(receipt: @receipt)
    end
  end
end
