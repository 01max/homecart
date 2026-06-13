module Matching
  # Entry point for receipt-line matching workflows.
  class QueueController < ApplicationController
    def index
      @groups = ReceiptLineMatching::QueueService.call
      @line_count = @groups.sum(&:line_count)
    end
  end
end
