module ProductCatalog
  # Finds catalogue records by normalized product brand, product, and variant names.
  class SearchService < ApplicationService
    Result = Data.define(:record, :record_type, :matched_attribute, :score)

    DEFAULT_LIMIT = 20
    MAX_LIMIT = 100
    MINIMUM_TRIGRAM_SCORE = 0.18

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
      ProductBrand
        .select(Arel.sql("product_brands.*, #{score_sql('product_brands.normalized_name')} AS normalized_name_score"))
        .where("#{score_sql('product_brands.normalized_name')} >= ?", MINIMUM_TRIGRAM_SCORE)
        .map do |product_brand|
        build_result(
          record: product_brand,
          record_type: :product_brand,
          candidate_scores: { normalized_name: read_score(product_brand, :normalized_name_score) }
        )
      end
    end

    def product_results
      Product.includes(:product_brand, :category)
        .select(Arel.sql("products.*, #{score_sql('products.normalized_name')} AS normalized_name_score"))
        .where("#{score_sql('products.normalized_name')} >= ?", MINIMUM_TRIGRAM_SCORE)
        .map do |product|
          build_result(
            record: product,
            record_type: :product,
            candidate_scores: { normalized_name: read_score(product, :normalized_name_score) }
          )
        end
    end

    def product_variant_results
      ProductVariant.includes(product: :product_brand)
        .joins(product: :product_brand)
        .select(Arel.sql(<<~SQL.squish))
          product_variants.*,
          #{score_sql('product_variants.normalized_name')} AS normalized_name_score,
          #{score_sql('products.normalized_name')} AS product_name_score,
          #{score_sql('product_brands.normalized_name')} AS product_brand_name_score
        SQL
        .where("#{variant_score_sql} >= ?", MINIMUM_TRIGRAM_SCORE)
        .map do |variant|
          build_result(
            record: variant,
            record_type: :product_variant,
            candidate_scores: {
              normalized_name: read_score(variant, :normalized_name_score),
              product_name: read_score(variant, :product_name_score),
              product_brand_name: read_score(variant, :product_brand_name_score)
            }
          )
        end
    end

    def build_result(record:, record_type:, candidate_scores:)
      matched_attribute, score = candidate_scores
        .max_by { |_attribute, candidate_score| candidate_score }

      Result.new(record: record, record_type: record_type, matched_attribute: matched_attribute, score: (score * 100).round(2))
    end

    def variant_score_sql
      score_sql(
        "product_variants.normalized_name",
        "products.normalized_name",
        "product_brands.normalized_name"
      )
    end

    def score_sql(*qualified_columns)
      "GREATEST(#{qualified_columns.map { |column| column_score_sql(column) }.join(', ')})"
    end

    def column_score_sql(qualified_column)
      <<~SQL.squish
        similarity(#{qualified_column}, #{quoted_normalized_query}),
        word_similarity(#{quoted_normalized_query}, #{qualified_column}),
        word_similarity(#{qualified_column}, #{quoted_normalized_query})
      SQL
    end

    def quoted_normalized_query
      ActiveRecord::Base.connection.quote(normalized_query)
    end

    def read_score(record, attribute)
      record.read_attribute(attribute).to_d
    end

    def normalized_query
      @normalized_query ||= NormalizeTextService.call(query)
    end

    def limit_value
      limit.to_i.clamp(1, MAX_LIMIT)
    end
  end
end
