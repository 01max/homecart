module Matching
  # Entry point for matching a single reviewed receipt.
  class ReceiptsController < ApplicationController
    def show
      @receipt = Receipt.includes(:receipt_lines, store: :retail_brand).find(params[:id])
      @entries = ReceiptLineMatching::ReceiptQueueService.call(receipt: @receipt)
    end
  end
end
