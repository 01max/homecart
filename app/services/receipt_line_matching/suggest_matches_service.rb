module ReceiptLineMatching
  # Produces deterministic product-variant suggestions for one receipt line.
  class SuggestMatchesService < ApplicationService
    Suggestion = Data.define(:product_variant, :reason, :confidence, :receipt_line_match, :search_result)

    DEFAULT_LIMIT = 5
    SEARCH_LIMIT = 20
    PRIOR_CONFIRMED_CONFIDENCE = 1.0

    def initialize(receipt_line:, limit: DEFAULT_LIMIT, persist: true)
      @receipt_line = receipt_line
      @limit = limit
      @persist = persist
    end

    def call
      return [] unless suggestible_receipt_line?

      suggestions.first(limit_value)
    end

    private

    attr_reader :receipt_line, :limit, :persist

    def suggestible_receipt_line?
      receipt_line.kind_item? && !ReceiptLineMatch.terminal_decisions.exists?(receipt_line: receipt_line)
    end

    def suggestions
      (prior_confirmed_suggestions + catalogue_search_suggestions).uniq(&:product_variant)
    end

    def prior_confirmed_suggestions
      prior_confirmed_variants.map do |variant|
        build_suggestion(
          product_variant: variant,
          reason: :prior_confirmed_label,
          confidence: PRIOR_CONFIRMED_CONFIDENCE
        )
      end
    end

    def prior_confirmed_variants
      ReceiptLineMatch.confirmed
        .includes(:receipt_line, :product_variant)
        .filter_map { |match| match.product_variant if same_normalized_label?(match) }
        .uniq
        .reject { |variant| rejected_variant_ids.include?(variant.id) }
    end

    def same_normalized_label?(match)
      normalized(match.label_snapshot) == normalized_label ||
        normalized(match.receipt_line.label) == normalized_label
    end

    def catalogue_search_suggestions
      ProductCatalog::SearchService.call(query: receipt_line.label, limit: SEARCH_LIMIT)
        .flat_map { |result| variants_for_search_result(result).map { |variant| [ variant, result ] } }
        .reject { |variant, _result| prior_confirmed_variant_ids.include?(variant.id) }
        .reject { |variant, _result| rejected_variant_ids.include?(variant.id) }
        .map { |variant, result| build_catalogue_suggestion(variant, result) }
    end

    def variants_for_search_result(result)
      case result.record
      when ProductVariant
        [ result.record ]
      when Product
        result.record.product_variants.order(:name).to_a
      when ProductBrand
        ProductVariant.joins(:product)
          .where(products: { product_brand_id: result.record.id })
          .order(:name)
          .to_a
      else
        []
      end
    end

    def build_catalogue_suggestion(variant, search_result)
      build_suggestion(
        product_variant: variant,
        reason: :catalogue_search,
        confidence: confidence_for(search_result),
        search_result: search_result
      )
    end

    def build_suggestion(product_variant:, reason:, confidence:, search_result: nil)
      Suggestion.new(
        product_variant: product_variant,
        reason: reason,
        confidence: confidence,
        receipt_line_match: persisted_suggestion(product_variant, confidence),
        search_result: search_result
      )
    end

    def persisted_suggestion(product_variant, confidence)
      return unless persist

      ReceiptLineMatch.find_or_initialize_by(
        receipt_line: receipt_line,
        product_variant: product_variant,
        status: "suggested"
      ).tap do |match|
        match.source = "heuristic"
        match.confidence = confidence
        match.label_snapshot = receipt_line.label
        match.save!
      end
    end

    def confidence_for(search_result)
      (search_result.score.to_d / 100).clamp(0, 1)
    end

    def rejected_variant_ids
      @rejected_variant_ids ||= ReceiptLineMatch.rejected
        .where(receipt_line: receipt_line)
        .where.not(product_variant_id: nil)
        .pluck(:product_variant_id)
        .to_set
    end

    def prior_confirmed_variant_ids
      @prior_confirmed_variant_ids ||= prior_confirmed_variants.map(&:id).to_set
    end

    def normalized_label
      @normalized_label ||= normalized(receipt_line.label)
    end

    def normalized(label)
      ProductCatalog::NormalizeTextService.call(label)
    end

    def limit_value
      limit.to_i.clamp(1, SEARCH_LIMIT)
    end
  end
end
