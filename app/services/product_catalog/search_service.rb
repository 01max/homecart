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
      normalized_name_score = score_node(product_brand_table[:normalized_name])

      ProductBrand
        .select(product_brand_table[Arel.star], normalized_name_score.as("normalized_name_score"))
        .where(normalized_name_score.gteq(MINIMUM_TRIGRAM_SCORE))
        .map do |product_brand|
          build_result(
            record: product_brand,
            record_type: :product_brand,
            candidate_scores: { normalized_name: read_score(product_brand, :normalized_name_score) }
          )
        end
    end

    def product_results
      normalized_name_score = score_node(product_table[:normalized_name])

      Product.includes(:product_brand, :category)
        .select(product_table[Arel.star], normalized_name_score.as("normalized_name_score"))
        .where(normalized_name_score.gteq(MINIMUM_TRIGRAM_SCORE))
        .map do |product|
          build_result(
            record: product,
            record_type: :product,
            candidate_scores: { normalized_name: read_score(product, :normalized_name_score) }
          )
        end
    end

    def product_variant_results
      normalized_name_score = score_node(product_variant_table[:normalized_name])
      product_name_score = score_node(product_table[:normalized_name])
      product_brand_name_score = score_node(product_brand_table[:normalized_name])
      variant_score = score_node(
        product_variant_table[:normalized_name],
        product_table[:normalized_name],
        product_brand_table[:normalized_name]
      )

      ProductVariant.includes(product: :product_brand)
        .joins(product: :product_brand)
        .select(
          product_variant_table[Arel.star],
          normalized_name_score.as("normalized_name_score"),
          product_name_score.as("product_name_score"),
          product_brand_name_score.as("product_brand_name_score")
        )
        .where(variant_score.gteq(MINIMUM_TRIGRAM_SCORE))
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

    def score_node(*attributes)
      Arel::Nodes::NamedFunction.new(
        "GREATEST",
        attributes.flat_map { |attribute| column_score_nodes(attribute) }
      )
    end

    def column_score_nodes(attribute)
      [
        Arel::Nodes::NamedFunction.new("similarity", [ attribute, normalized_query_node ]),
        Arel::Nodes::NamedFunction.new("word_similarity", [ normalized_query_node, attribute ]),
        Arel::Nodes::NamedFunction.new("word_similarity", [ attribute, normalized_query_node ])
      ]
    end

    def normalized_query_node
      @normalized_query_node ||= Arel::Nodes.build_quoted(normalized_query)
    end

    def product_brand_table
      ProductBrand.arel_table
    end

    def product_table
      Product.arel_table
    end

    def product_variant_table
      ProductVariant.arel_table
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
