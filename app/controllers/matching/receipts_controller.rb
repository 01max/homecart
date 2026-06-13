module Matching
  # Entry point for matching a single reviewed receipt.
  class ReceiptsController < ApplicationController
    def show
      @receipt = Receipt.includes(:receipt_lines, store: :retail_brand).find(params[:id])
      return redirect_to receipt_path(@receipt), alert: t(".errors.receipt_not_reviewed") unless @receipt.reviewed?

      @entries = ReceiptLineMatching::ReceiptQueueService.call(receipt: @receipt)
    end
  end
end
