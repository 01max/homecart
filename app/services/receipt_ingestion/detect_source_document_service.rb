module ReceiptIngestion
  # Classifies a source document from extracted receipt text.
  #
  # The service owns the persistence boundary for source-detection attempts.
  # Rule-specific parser and store detection are added behind the selection
  # methods so the result envelope stays stable as the detector grows.
  class DetectSourceDocumentService < ApplicationService
    ParserRule = Data.define(:format, :tier, :marker, :regexp)
    ParserMatch = Data.define(:format, :tier, :marker)
    StoreMatch = Data.define(:store, :evidence)
    Selection = Data.define(:value, :confidence, :evidence)
    Result = Data.define(
      :status,
      :parser_format,
      :parser_confidence,
      :store,
      :store_confidence,
      :evidence,
      :detection,
      :source_document
    ) do
      def classified?
        status == SourceDocumentDetection::STATUSES.fetch(:classified)
      end

      def needs_classification?
        status == SourceDocumentDetection::STATUSES.fetch(:needs_classification)
      end
    end

    PARSER_RULES = [
      ParserRule.new(
        SourceDocument::PARSER_FORMATS.fetch(:leclerc_web_v1),
        :hard,
        "leclerc_web_payment",
        /\bCB\s+Web\s+(?:Drive|C&C)\b/i
      ),
      ParserRule.new(
        SourceDocument::PARSER_FORMATS.fetch(:leclerc_paper_v2),
        :hard,
        "leclerc_paper_vat_table",
        /\bCode\s+HT\s+TVA\s+TTC\b/i
      ),
      ParserRule.new(
        SourceDocument::PARSER_FORMATS.fetch(:u_paper_v2),
        :hard,
        "u_omnipos_version",
        /\bOmniPOS\s+version\b/i
      ),
      ParserRule.new(
        SourceDocument::PARSER_FORMATS.fetch(:u_paper_v2),
        :hard,
        "u_omnipos_sale_banner",
        /^\s*\*{3}\s*VENTE\s*\*{3}\s*$/i
      ),
      ParserRule.new(
        SourceDocument::PARSER_FORMATS.fetch(:u_paper_v1),
        :hard,
        "u_legacy_hash_footer",
        /^\s*Hash:/i
      ),
      ParserRule.new(
        SourceDocument::PARSER_FORMATS.fetch(:u_paper_v1),
        :fallback,
        "u_legacy_section_marker",
        /^\s*>>>>\s+/i
      ),
      ParserRule.new(
        SourceDocument::PARSER_FORMATS.fetch(:auchan_paper_v1),
        :hard,
        "auchan_waaoh_account",
        /\bWAAOH\b/i
      ),
      ParserRule.new(
        SourceDocument::PARSER_FORMATS.fetch(:auchan_paper_v1),
        :hard,
        "auchan_selfscan_section",
        /\bSelfscan\b/i
      ),
      ParserRule.new(
        SourceDocument::PARSER_FORMATS.fetch(:auchan_paper_v1),
        :hard,
        "auchan_tr_totals",
        /\bTOT\.\s+ARTICLES\s+ELIGIBLES\s+TR\b/i
      ),
      ParserRule.new(
        SourceDocument::PARSER_FORMATS.fetch(:leclerc_paper_v1),
        :fallback,
        "leclerc_paper_legacy_ticket_line",
        /^\s*\d{2}\/\d{2}\/\d{2}\s+\d\s+\w{4}\s+\d{2}\w{3}\s*$/i
      )
    ].freeze

    PARSER_FORMAT_CHANNELS = {
      SourceDocument::PARSER_FORMATS.fetch(:auchan_paper_v1) => %w[physical],
      SourceDocument::PARSER_FORMATS.fetch(:leclerc_paper_v1) => %w[physical],
      SourceDocument::PARSER_FORMATS.fetch(:leclerc_paper_v2) => %w[physical],
      SourceDocument::PARSER_FORMATS.fetch(:leclerc_web_v1) => %w[drive click_collect],
      SourceDocument::PARSER_FORMATS.fetch(:u_paper_v1) => %w[physical],
      SourceDocument::PARSER_FORMATS.fetch(:u_paper_v2) => %w[physical]
    }.freeze

    STORE_IDENTIFIER_ARRAY_KEYS = %w[
      receipt_header_patterns
      legal_entities
    ].freeze

    STORE_HINT_OBJECT_KEYS = %w[
      detection_hints
      private_detection_hints
    ].freeze

    # @param text_extraction [TextExtraction] extraction attempt used as detection evidence
    def initialize(text_extraction:)
      @text_extraction = text_extraction
      @source_document = text_extraction.source_document
    end

    # @return [Result] persisted detection plus the selected source fields
    # @raise [ActiveRecord::RecordInvalid] when selected fields cannot be persisted
    def call
      parser_selection = select_parser_format
      store_selection = select_store(parser_format: parser_selection.value)
      status = status_for(parser_selection: parser_selection, store_selection: store_selection)
      evidence = parser_selection.evidence + store_selection.evidence

      ActiveRecord::Base.transaction do
        detection = create_detection(
          status: status,
          parser_selection: parser_selection,
          store_selection: store_selection,
          evidence: evidence
        )
        update_source_document(status: status, parser_selection: parser_selection, store_selection: store_selection)

        Result.new(
          status: status,
          parser_format: parser_selection.value,
          parser_confidence: parser_selection.confidence,
          store: store_selection.value,
          store_confidence: store_selection.confidence,
          evidence: evidence,
          detection: detection,
          source_document: source_document.reload
        )
      end
    end

    private

    attr_reader :text_extraction, :source_document

    def select_parser_format
      parser_format = explicit_parser_format
      return manual_selection(parser_format, explicit_parser_format_evidence(parser_format)) if parser_format.present?

      detected_parser_selection
    end

    def select_store(parser_format:)
      return manual_selection(source_document.store, explicit_store_evidence) if source_document.store.present?

      detected_store_selection(parser_format: parser_format)
    end

    def explicit_parser_format
      SourceDocument.parser_formats.fetch(source_document.parser_format) if source_document.parser_format.present?
    end

    def detected_parser_selection
      matches = parser_format_matches
      considered_matches = preferred_parser_matches(matches)
      formats = considered_matches.map(&:format).uniq

      return none_selection(code: "parser_format_not_detected") if formats.empty?
      return high_confidence_selection(formats.sole, parser_marker_evidence(considered_matches)) if formats.one?

      ambiguous_parser_selection(considered_matches)
    end

    def parser_format_matches
      PARSER_RULES.filter_map do |rule|
        ParserMatch.new(rule.format, rule.tier, rule.marker) if parser_text.match?(rule.regexp)
      end
    end

    def preferred_parser_matches(matches)
      hard_matches = matches.select { |match| match.tier == :hard }
      hard_matches.presence || matches
    end

    def parser_text
      text_extraction.text.to_s
    end

    def detected_store_selection(parser_format:)
      matches = store_matches(parser_format: parser_format)

      return none_selection(code: "store_not_detected") if matches.empty?
      return high_confidence_selection(matches.sole.store, matches.sole.evidence) if matches.one?

      ambiguous_store_selection(matches)
    end

    def store_matches(parser_format:)
      store_scope(parser_format: parser_format).filter_map do |store|
        evidence = store_evidence(store, parser_format: parser_format)
        StoreMatch.new(store, evidence) if evidence.any?
      end
    end

    def store_scope(parser_format:)
      scope = Store.includes(:retail_brand)
      channels = PARSER_FORMAT_CHANNELS[parser_format]

      channels.present? ? scope.where(channel: channels) : scope
    end

    def store_evidence(store, parser_format:)
      evidence = []
      evidence.concat(brand_alias_evidence(store))
      evidence.concat(location_name_evidence(store))
      evidence.concat(identifier_array_evidence(store))
      evidence.concat(store_code_evidence(store))
      evidence.concat(hint_object_evidence(store))
      evidence.concat(default_parser_format_evidence(store, parser_format: parser_format)) if evidence.any?
      evidence
    end

    def manual_selection(value, evidence)
      Selection.new(value, SourceDocumentDetection::CONFIDENCES.fetch(:manual), [ evidence ])
    end

    def high_confidence_selection(value, evidence)
      Selection.new(
        value,
        SourceDocumentDetection::CONFIDENCES.fetch(:high),
        evidence
      )
    end

    def ambiguous_store_selection(matches)
      evidence = matches.flat_map(&:evidence)
      evidence << {
        "code" => "store_ambiguous",
        "store_ids" => matches.map { |match| match.store.id }.sort
      }

      Selection.new(nil, SourceDocumentDetection::CONFIDENCES.fetch(:none), evidence)
    end

    def ambiguous_parser_selection(matches)
      evidence = parser_marker_evidence(matches)
      evidence << {
        "code" => "parser_format_ambiguous",
        "parser_formats" => matches.map(&:format).uniq.sort
      }

      Selection.new(nil, SourceDocumentDetection::CONFIDENCES.fetch(:none), evidence)
    end

    def none_selection(code:)
      Selection.new(nil, SourceDocumentDetection::CONFIDENCES.fetch(:none), [ { "code" => code } ])
    end

    def parser_marker_evidence(matches)
      matches.map do |match|
        {
          "code" => "parser_format_marker",
          "parser_format" => match.format,
          "marker" => match.marker
        }
      end
    end

    def brand_alias_evidence(store)
      store.retail_brand.aliases.filter_map do |brand_alias|
        metadata_match_evidence(store, source: "retail_brand.aliases", value: brand_alias) if text_matches?(brand_alias)
      end
    end

    def location_name_evidence(store)
      return [] unless text_matches?(store.location_name)

      [
        metadata_match_evidence(store, source: "store.location_name", value: store.location_name)
      ]
    end

    def identifier_array_evidence(store)
      STORE_IDENTIFIER_ARRAY_KEYS.flat_map do |key|
        Array(store.identifiers[key]).filter_map do |value|
          if text_matches?(value)
            metadata_match_evidence(store, source: "store.identifiers.#{key}", value: value)
          end
        end
      end
    end

    def store_code_evidence(store)
      Array(store.identifiers["receipt_store_codes"]).filter_map do |code|
        if text_matches_token?(code)
          metadata_match_evidence(store, source: "store.identifiers.receipt_store_codes", value: code)
        end
      end
    end

    def hint_object_evidence(store)
      STORE_HINT_OBJECT_KEYS.flat_map do |key|
        nested_identifier_values(store.identifiers[key], "store.identifiers.#{key}").filter_map do |source, value|
          metadata_match_evidence(store, source: source, value: value) if text_matches?(value)
        end
      end
    end

    def default_parser_format_evidence(store, parser_format:)
      return [] if parser_format.blank?
      return [] unless store.identifiers["default_parser_format"] == parser_format

      [
        {
          "code" => "store_default_parser_format",
          "store_id" => store.id,
          "parser_format" => parser_format
        }
      ]
    end

    def metadata_match_evidence(store, source:, value:)
      {
        "code" => "store_metadata_match",
        "store_id" => store.id,
        "source" => source,
        "value" => value
      }
    end

    def nested_identifier_values(value, source)
      case value
      when Hash
        value.flat_map { |key, nested_value| nested_identifier_values(nested_value, "#{source}.#{key}") }
      when Array
        value.flat_map { |nested_value| nested_identifier_values(nested_value, source) }
      when String
        [ [ source, value ] ]
      else
        []
      end
    end

    def text_matches?(value)
      normalized_value = normalize_detection_text(value)
      return false if normalized_value.length < 3

      normalized_parser_text.match?(normalized_match_regexp(normalized_value))
    end

    def text_matches_token?(value)
      normalized_value = normalize_detection_text(value)
      return false if normalized_value.length < 3

      normalized_parser_text.match?(normalized_token_regexp(normalized_value))
    end

    def normalized_match_regexp(value)
      /(?:\A|\s)#{Regexp.escape(value)}(?:\s|\z)/
    end

    def normalized_token_regexp(value)
      /\b#{Regexp.escape(value)}\b/
    end

    def normalized_parser_text
      @normalized_parser_text ||= normalize_detection_text(parser_text)
    end

    def normalize_detection_text(value)
      value.to_s.unicode_normalize(:nfd)
        .gsub(/\p{Mn}/, "")
        .downcase
        .gsub(/[^a-z0-9]+/, " ")
        .squeeze(" ")
        .strip
    end

    def explicit_parser_format_evidence(parser_format)
      {
        "code" => "explicit_parser_format",
        "parser_format" => parser_format
      }
    end

    def explicit_store_evidence
      {
        "code" => "explicit_store",
        "store_id" => source_document.store_id
      }
    end

    def status_for(parser_selection:, store_selection:)
      if parser_selection.value.present? && store_selection.value.present?
        SourceDocumentDetection::STATUSES.fetch(:classified)
      else
        SourceDocumentDetection::STATUSES.fetch(:needs_classification)
      end
    end

    def create_detection(status:, parser_selection:, store_selection:, evidence:)
      SourceDocumentDetection.create!(
        source_document: source_document,
        text_extraction: text_extraction,
        status: status,
        parser_format: parser_selection.value,
        parser_confidence: parser_selection.confidence,
        store: store_selection.value,
        store_confidence: store_selection.confidence,
        evidence: evidence
      )
    end

    def update_source_document(status:, parser_selection:, store_selection:)
      source_document.update!(
        source_detection_status: status,
        parser_format: parser_selection.value,
        store: store_selection.value
      )
    end
  end
end
