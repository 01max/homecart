module Parser
  module Leclerc
    module Paper
      class V2 < Parser::Base
        FORMAT = Parser::Registry::FORMATS.fetch(:leclerc_paper_v2)

        HEADER_PATTERN = /\ACaisse (?<register>\S+) (?<day>\d{2}) (?<month>\p{L}+) (?<year>\d{4}) (?<hour>\d{2}):(?<minute>\d{2})\z/
        TICKET_PATTERN = /\ATicket \d{2}\/\d{2}\/\d{2}\s+\d+\s+(?<ticket>.+)\z/
        SECTION_PATTERN = /\A>>\s+(?<section>.+)\z/
        BODY_HEADER_PATTERN = /\ATTC\s+TVA\z/
        ITEM_LINE_PATTERN = /\A(?<label>.+?)\s+(?<amount>\d+\.\d{2})\s+(?<vat_code>\d+)\z/
        QUANTITY_LINE_PATTERN = /\A(?<quantity>\d+(?:[,.]\d+)?)\s+X\s+(?<unit_price>\d+\.\d{2})€\s+(?<total>\d+\.\d{2})\s+(?<vat_code>\d+)\z/
        TOTAL_PATTERN = /\ATotal (?<count>\d+) articles?\s+(?<amount>\d+\.\d{2})\z/
        PAYMENT_PATTERN = /\A(?<raw_label>CB|Bon achat carte|Bon immediat)\s+(?<amount>\d+\.\d{2})\z/
        VAT_ROW_PATTERN = /\A(?<code>\d+)\s+(?<rate_whole>\d+)%\s*(?<rate_decimal>\d{2})\s+[-\d.]+\s+[-\d.]+\s+[-\d.]+\z/

        Parser::Registry.register(FORMAT, self)

        def call
          result = result_envelope(
            receipt: receipt_attributes,
            lines: line_attributes,
            promotions: [],
            payments: payment_attributes
          )
          validator_results = [ validate_totals_sum(result), validate_article_count(result), validate_payments_sum(result) ]
          result.receipt[:parser_status] = validator_results.all? && warnings.empty? ? "parsed" : "needs_review"

          result
        end

        private

        def receipt_attributes
          {
            parser_format: FORMAT,
            purchased_at: purchased_at,
            register_number: header_match&.[](:register),
            ticket_number: ticket_number,
            cashier_code: nil,
            total_cents: total_cents,
            declared_article_count: declared_article_count,
            parser_status: "parsed",
            parser_warnings: warnings
          }
        end

        def line_attributes
          parsed_lines.map.with_index(1) { |line, position| line.merge(position: position) }
        end

        def parsed_lines
          @parsed_lines ||= parse_receipt_lines
        end

        def parse_receipt_lines
          state = LineState.new
          text_lines.each_with_object([]) do |line, parsed|
            handle_body_marker(line, state)
            handle_section_marker(line, state)
            next if skip_line?(line, state)

            parse_receipt_line(line, state, parsed)
          end
        end

        def handle_body_marker(line, state)
          return unless line.match?(BODY_HEADER_PATTERN)

          state.items_started = true
        end

        def handle_section_marker(line, state)
          section_match = line.match(SECTION_PATTERN)
          return unless section_match

          state.items_started = true
          state.section_label = section_match[:section]
        end

        def skip_line?(line, state)
          return true if line.match?(BODY_HEADER_PATTERN) || line.match?(SECTION_PATTERN)
          return true if state.items_finished?
          return true unless state.items_started?

          return state.items_finished = true if line.match?(TOTAL_PATTERN)

          false
        end

        def parse_receipt_line(line, state, parsed)
          if (quantity_match = line.match(QUANTITY_LINE_PATTERN))
            parsed << parse_quantity_line(quantity_match, state)
            return state.pending_label = nil
          end

          item_match = line.match(ITEM_LINE_PATTERN)
          return state.pending_label = clean_label(line) unless item_match

          parsed << parse_item_line(item_match, line, state)
          state.pending_label = nil
        end

        def parse_item_line(match, raw_text, state)
          label = clean_label(match[:label])

          {
            raw_text: raw_text,
            label: normalize_label(label),
            label_truncated: label_truncated?(label),
            quantity: BigDecimal("1"),
            unit_of_measure: "piece",
            unit_price_cents: nil,
            total_cents: cents_from(match[:amount]),
            vat_rate_bp: vat_rate_bp_for(match[:vat_code]),
            tr_eligible: false,
            section_label: state.section_label,
            kind: "item"
          }
        end

        def parse_quantity_line(match, state)
          label = state.pending_label
          raw_text = [ label, match.to_s ].join("\n")

          {
            raw_text: raw_text,
            label: normalize_label(label),
            label_truncated: label_truncated?(label),
            quantity: decimal_from(match[:quantity]),
            unit_of_measure: "piece",
            unit_price_cents: cents_from(match[:unit_price]),
            total_cents: cents_from(match[:total]),
            vat_rate_bp: vat_rate_bp_for(match[:vat_code]),
            tr_eligible: false,
            section_label: state.section_label,
            kind: "item"
          }
        end

        def payment_attributes
          text_lines.filter_map.with_index(1) do |line, index|
            match = line.match(PAYMENT_PATTERN)
            next unless match

            {
              position: index,
              raw_label: match[:raw_label],
              category: payment_category(match[:raw_label]),
              amount_cents: cents_from(match[:amount])
            }
          end
        end

        def payment_category(raw_label)
          raw_label == "CB" ? "bank_card" : "other"
        end

        def purchased_at
          return unless header_match

          Time.zone.local(
            header_match[:year].to_i,
            french_month_number(header_match[:month]),
            header_match[:day].to_i,
            header_match[:hour].to_i,
            header_match[:minute].to_i
          )
        end

        def header_match
          @header_match ||= text_lines.lazy.filter_map { |line| line.match(HEADER_PATTERN) }.first
        end

        def ticket_number
          text_lines.lazy.filter_map { |line| line.match(TICKET_PATTERN)&.[](:ticket) }.first
        end

        def total_cents
          cents_from(total_match&.[](:amount))
        end

        def declared_article_count
          total_match&.[](:count)&.to_i
        end

        def total_match
          @total_match ||= text_lines.lazy.filter_map { |line| line.match(TOTAL_PATTERN) }.first
        end

        def vat_rate_bp_for(vat_code)
          vat_rates_by_code.fetch(vat_code) do
            add_warning(code: "missing_vat_code", detail: "No VAT table row found for code #{vat_code}")
            nil
          end
        end

        def vat_rates_by_code
          @vat_rates_by_code ||= text_lines.filter_map do |line|
            match = line.match(VAT_ROW_PATTERN)
            next unless match

            [ match[:code], (match[:rate_whole].to_i * 100) + match[:rate_decimal].to_i ]
          end.to_h
        end

        def clean_label(label)
          label.delete_prefix("*").strip
        end

        def normalize_label(label)
          label.sub(/\s*\.\.\z/, "").strip
        end

        def label_truncated?(label)
          label.match?(/\s*\.\.\z/)
        end

        class LineState
          attr_accessor :section_label, :pending_label

          def initialize
            @items_started = false
            @items_finished = false
          end

          def items_started?
            @items_started
          end

          def items_started=(value)
            @items_started = value
          end

          def items_finished?
            @items_finished
          end

          def items_finished=(value)
            @items_finished = value
          end
        end
      end
    end
  end
end
