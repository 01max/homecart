module ProductCatalog
  # Finds catalogue records by normalized product brand, product, and variant names.
  class SearchService < ApplicationService
    Result = Data.define(:record, :record_type, :matched_attribute, :score)

    DEFAULT_LIMIT = 20
    MAX_LIMIT = 100

    def initialize(query:, limit: DEFAULT_LIMIT)
      @query = query
      @limit = limit
    end

    def call
      return [] if normalized_query.blank?

      ranked_results.first(limit_value)
    end

    private

    attr_reader :query, :limit

    def ranked_results
      (product_brand_results + product_results + product_variant_results)
        .sort_by { |result| [ -result.score, result.record_type.to_s, result.record.name ] }
    end

    def product_brand_results
      ProductBrand.where(match_condition("product_brands.normalized_name")).map do |product_brand|
        build_result(
          record: product_brand,
          record_type: :product_brand,
          candidate_scores: { normalized_name: product_brand.normalized_name }
        )
      end
    end

    def product_results
      Product.includes(:product_brand, :category)
        .where(match_condition("products.normalized_name"))
        .map do |product|
          build_result(
            record: product,
            record_type: :product,
            candidate_scores: { normalized_name: product.normalized_name }
          )
        end
    end

    def product_variant_results
      ProductVariant.includes(product: :product_brand)
        .joins(product: :product_brand)
        .where(variant_match_condition)
        .map do |variant|
          build_result(
            record: variant,
            record_type: :product_variant,
            candidate_scores: {
              normalized_name: variant.normalized_name,
              product_name: variant.product.normalized_name,
              product_brand_name: variant.product.product_brand.normalized_name
            }
          )
        end
    end

    def build_result(record:, record_type:, candidate_scores:)
      matched_attribute, score = candidate_scores
        .transform_values { |candidate| score(candidate) }
        .max_by { |_attribute, candidate_score| candidate_score }

      Result.new(record: record, record_type: record_type, matched_attribute: matched_attribute, score: score)
    end

    def variant_match_condition
      [
        match_condition("product_variants.normalized_name"),
        match_condition("products.normalized_name"),
        match_condition("product_brands.normalized_name")
      ].reduce(&:or)
    end

    def match_condition(qualified_column)
      tokens
        .map { |token| arel_table_matches(qualified_column, token) }
        .reduce(&:or)
    end

    def arel_table_matches(qualified_column, token)
      Arel.sql(qualified_column).matches("%#{ActiveRecord::Base.sanitize_sql_like(token)}%")
    end

    def score(candidate)
      candidate = candidate.to_s
      matching_tokens = tokens.count { |token| candidate.include?(token) }

      (candidate == normalized_query ? 100 : 0) +
        (normalized_query.include?(candidate) ? 60 : 0) +
        (candidate.start_with?(tokens.first) ? 30 : 0) +
        (matching_tokens * 20)
    end

    def tokens
      @tokens ||= normalized_query.split
    end

    def normalized_query
      @normalized_query ||= NormalizeTextService.call(query)
    end

    def limit_value
      limit.to_i.clamp(1, MAX_LIMIT)
    end
  end
end
