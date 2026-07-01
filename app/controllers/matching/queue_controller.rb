module Matching
  # Entry point for receipt-line matching workflows.
  class QueueController < ApplicationController
    def index
      @label_filter = params[:label_filter].to_s.strip
      @sort_column = queue_sort_column
      @sort_direction = queue_sort_direction(@sort_column)
      @groups = ReceiptLineMatching::QueueService.call(
        label_filter: @label_filter,
        sort: @sort_column,
        direction: @sort_direction
      )
      @line_count = @groups.sum(&:line_count)
      @pagy, @groups = pagy(@groups)
    end

    private

    def queue_sort_column
      sort = params[:sort].presence
      return sort if ReceiptLineMatching::QueueService::SORT_FIELDS.include?(sort)

      ReceiptLineMatching::QueueService::DEFAULT_SORT
    end

    def queue_sort_direction(sort_column)
      direction = params[:direction].presence
      return direction if ReceiptLineMatching::QueueService::DIRECTIONS.include?(direction)

      ReceiptLineMatching::QueueService::DEFAULT_DIRECTIONS.fetch(sort_column)
    end
  end
end
