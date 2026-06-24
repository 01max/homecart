module Matching
  # Focused page for one current global matching queue group.
  class GroupsController < ApplicationController
    def show
      @receipt_line = ReceiptLine.find(params[:id])
      @queue_params = queue_context_params
      @group = current_group

      return redirect_to matching_queue_path(@queue_params), alert: t(".errors.stale_group") if @group.blank?

      @receipt_lines = @group.receipt_lines
    end

    private

    def current_group
      normalized_label = ProductCatalog::NormalizeTextService.call(@receipt_line.label)

      ReceiptLineMatching::QueueService.call.find { |group| group.normalized_label == normalized_label }
    end

    def queue_context_params
      {
        label_filter: params[:label_filter].to_s.strip.presence,
        sort: queue_sort_column,
        direction: queue_sort_direction(queue_sort_column)
      }.compact
    end

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
