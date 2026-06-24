module Matching
  # Focused page for one current global matching queue group.
  class GroupsController < ApplicationController
    Entry = Data.define(
      :group,
      :receipt_line,
      :suggestions,
      :variant_search_query,
      :variant_search_results,
      :bulk_preview,
      :bulk_preview_variant
    )

    def show
      @receipt_line = ReceiptLine.find(params[:id])
      @queue_params = queue_context_params
      @variant_search_query = params[:variant_search_query].to_s.strip
      @bulk_preview_variant_id = params[:bulk_preview_variant_id].presence
      @group = current_group

      return redirect_to matching_queue_path(@queue_params), alert: t(".errors.stale_group") if @group.blank?

      @previous_group, @next_group = adjacent_groups
      @receipt_lines = @group.receipt_lines
      @categories = Category.includes(:parent).order(:normalized_name)
      @comparison_units = ComparisonUnit.order(:normalized_name)
      @retail_brands = RetailBrand.order(:name)
      @entry = build_entry
    end

    private

    def current_group
      normalized_label = ProductCatalog::NormalizeTextService.call(@receipt_line.label)

      queue_groups.find { |group| group.normalized_label == normalized_label }
    end

    def adjacent_groups
      current_index = queue_groups.index { |group| group.normalized_label == @group.normalized_label }

      [ previous_group(current_index), next_group(current_index) ]
    end

    def previous_group(current_index)
      return if current_index.blank? || current_index.zero?

      queue_groups[current_index - 1]
    end

    def next_group(current_index)
      return if current_index.blank?

      queue_groups[current_index + 1]
    end

    def queue_groups
      @queue_groups ||= ReceiptLineMatching::QueueService.call(
        label_filter: @queue_params[:label_filter],
        sort: @queue_params[:sort],
        direction: @queue_params[:direction]
      )
    end

    def build_entry
      receipt_line = @group.receipt_lines.first

      Entry.new(
        group: @group,
        receipt_line: receipt_line,
        suggestions: ReceiptLineMatching::SuggestMatchesService.call(receipt_line: receipt_line, persist: false),
        variant_search_query: variant_search_query_for,
        variant_search_results: variant_search_results,
        bulk_preview: bulk_preview,
        bulk_preview_variant: bulk_preview_variant
      )
    end

    def variant_search_query_for
      @variant_search_query.presence || @group.representative_label
    end

    def variant_search_results
      return [] if @variant_search_query.blank?

      ProductCatalog::SearchService.call(query: @variant_search_query, limit: 20)
        .filter_map { |result| result.record if result.record_type == :product_variant }
    end

    def bulk_preview
      return if bulk_preview_variant.blank?

      ReceiptLineMatching::BulkConfirmService.preview(normalized_label: @group.normalized_label)
    end

    def bulk_preview_variant
      @bulk_preview_variant ||= ProductVariant.find_by(id: @bulk_preview_variant_id)
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
