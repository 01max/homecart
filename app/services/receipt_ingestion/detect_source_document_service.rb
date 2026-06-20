module ReceiptIngestion
  # Classifies a source document from extracted receipt text.
  #
  # The service owns the persistence boundary for source-detection attempts.
  # Rule-specific parser and store detection are added behind the selection
  # methods so the result envelope stays stable as the detector grows.
  class DetectSourceDocumentService < ApplicationService
    ParserRule = Data.define(:format, :tier, :marker, :regexp)
    ParserMatch = Data.define(:format, :tier, :marker)
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

    # @param text_extraction [TextExtraction] extraction attempt used as detection evidence
    def initialize(text_extraction:)
      @text_extraction = text_extraction
      @source_document = text_extraction.source_document
    end

    # @return [Result] persisted detection plus the selected source fields
    # @raise [ActiveRecord::RecordInvalid] when selected fields cannot be persisted
    def call
      parser_selection = select_parser_format
      store_selection = select_store
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

    def select_store
      return manual_selection(source_document.store, explicit_store_evidence) if source_document.store.present?

      none_selection(code: "store_detection_pending")
    end

    def explicit_parser_format
      SourceDocument.parser_formats.fetch(source_document.parser_format) if source_document.parser_format.present?
    end

    def detected_parser_selection
      matches = parser_format_matches
      considered_matches = preferred_parser_matches(matches)
      formats = considered_matches.map(&:format).uniq

      return none_selection(code: "parser_format_not_detected") if formats.empty?
      return detected_selection(formats.sole, considered_matches) if formats.one?

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

    def manual_selection(value, evidence)
      Selection.new(value, SourceDocumentDetection::CONFIDENCES.fetch(:manual), [ evidence ])
    end

    def detected_selection(value, matches)
      Selection.new(
        value,
        SourceDocumentDetection::CONFIDENCES.fetch(:high),
        parser_marker_evidence(matches)
      )
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
