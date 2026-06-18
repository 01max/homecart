module Matching
  # Entry point for receipt-line matching workflows.
  class QueueController < ApplicationController
    Entry = Data.define(
      :group,
      :receipt_line,
      :suggestions,
      :variant_search_query,
      :variant_search_results,
      :bulk_preview,
      :bulk_preview_variant
    )

    def index
      @variant_search_label = params[:variant_search_label].to_s
      @variant_search_query = params[:variant_search_query].to_s.strip
      @bulk_preview_label = params[:bulk_preview_label].to_s
      @bulk_preview_variant_id = params[:bulk_preview_variant_id].presence
      @categories = Category.includes(:parent).order(:normalized_name)
      @comparison_units = ComparisonUnit.order(:normalized_name)
      @retail_brands = RetailBrand.order(:name)
      @groups = ReceiptLineMatching::QueueService.call
      @line_count = @groups.sum(&:line_count)
      @pagy, @groups = pagy(@groups)
      @entries = @groups.map { |group| build_entry(group) }
    end

    private

    attr_reader :variant_search_label, :variant_search_query, :bulk_preview_label, :bulk_preview_variant_id

    def build_entry(group)
      receipt_line = group.receipt_lines.first

      Entry.new(
        group: group,
        receipt_line: receipt_line,
        suggestions: ReceiptLineMatching::SuggestMatchesService.call(receipt_line: receipt_line, persist: false),
        variant_search_query: search_query_for(group),
        variant_search_results: variant_search_results_for(group),
        bulk_preview: bulk_preview_for(group),
        bulk_preview_variant: bulk_preview_variant_for(group)
      )
    end

    def search_query_for(group)
      searching_group?(group) ? variant_search_query : group.representative_label
    end

    def variant_search_results_for(group)
      return [] unless searching_group?(group) && variant_search_query.present?

      ProductCatalog::SearchService.call(query: variant_search_query, limit: 20)
        .filter_map { |result| result.record if result.record_type == :product_variant }
    end

    def searching_group?(group)
      variant_search_label == group.normalized_label
    end

    def bulk_preview_for(group)
      return unless previewing_group?(group)

      ReceiptLineMatching::BulkConfirmService.preview(normalized_label: group.normalized_label)
    end

    def bulk_preview_variant_for(group)
      return unless previewing_group?(group)

      ProductVariant.find_by(id: bulk_preview_variant_id)
    end

    def previewing_group?(group)
      bulk_preview_label == group.normalized_label && bulk_preview_variant_id.present?
    end
  end
end
