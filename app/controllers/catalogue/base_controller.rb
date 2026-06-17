module Catalogue
  # Shared helpers for catalogue management controllers.
  class BaseController < ApplicationController
    private

    def assign_catalogue_identity(record, name)
      record.name = name
      record.normalized_name = ProductCatalog::NormalizeTextService.call(name)
      record.slug = name.to_s.parameterize
    end

    def blank_to_nil(value)
      value.presence
    end

    def catalogue_ransack_search(scope, default_sort:)
      search = scope.ransack(catalogue_ransack_params)
      search.sorts = default_sort if search.sorts.empty?
      search
    end

    def catalogue_ransack_params
      params[:q]&.permit(:s) || {}
    end

    def load_catalogue_variant_search_results
      @catalogue_search_query = params[:catalogue_search_query].to_s.strip
      @catalogue_variant_search_results = []
      return if @catalogue_search_query.blank?

      @catalogue_variant_search_results = ProductCatalog::SearchService
        .call(query: @catalogue_search_query, limit: 20)
        .select { |result| result.record_type == :product_variant }
    end

    def redirect_with_record_errors(path, record)
      redirect_to path, alert: record.errors.full_messages.to_sentence
    end
  end
end
