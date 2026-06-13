module Matching
  # Entry point for receipt-line matching workflows.
  class QueueController < ApplicationController
    Entry = Data.define(:group, :receipt_line, :suggestions, :variant_search_query, :variant_search_results)

    def index
      @variant_search_label = params[:variant_search_label].to_s
      @variant_search_query = params[:variant_search_query].to_s.strip
      @categories = Category.includes(:parent).order(:normalized_name)
      @comparison_units = ComparisonUnit.order(:normalized_name)
      @retail_brands = RetailBrand.order(:name)
      @groups = ReceiptLineMatching::QueueService.call
      @entries = @groups.map { |group| build_entry(group) }
      @line_count = @groups.sum(&:line_count)
    end

    private

    attr_reader :variant_search_label, :variant_search_query

    def build_entry(group)
      receipt_line = group.receipt_lines.first

      Entry.new(
        group: group,
        receipt_line: receipt_line,
        suggestions: ReceiptLineMatching::SuggestMatchesService.call(receipt_line: receipt_line),
        variant_search_query: search_query_for(group),
        variant_search_results: variant_search_results_for(group)
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
  end
end
