require "bigdecimal"

module Parser
  module Auchan
    module Paper
      class V1 < Parser::Base
        FORMAT = Parser::Registry::FORMATS.fetch(:auchan_paper_v1)
        SECTION_SELFS_CAN = "Selfscan"
        SECTION_DISCOUNTS = "Articles avec Remise"

        ITEM_LINE_PATTERN = /\A(?<tr_marker>\*)?(?<label>.+?)\s+(?:(?<quantity>\d+(?:[,.]\d+)?)\*(?<unit_price>\d+,\d{2})\s+)?(?<total>-?\d+,\d{2})\z/
        DATE_PATTERN = /\ALe (?<day>\d{2}) (?<month>\p{L}+) (?<year>\d{4}) à (?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})\z/
        REGISTER_PATTERN = /\ACaisse\s*:\s*(?<register>\d+)\s+Ticket\s*:\s*(?<ticket>\d+)\z/

        Parser::Registry.register(FORMAT, self)

        def call
          result = result_envelope(
            receipt: receipt_attributes,
            lines: line_attributes,
            promotions: [],
            payments: payment_attributes
          )
          add_scan_warnings
          validator_results = [ validate_totals_sum(result), validate_article_count(result), validate_payments_sum(result) ]
          result.receipt[:parser_status] = parsed_status(validator_results)

          result
        end

        private

        def receipt_attributes
          {
            parser_format: FORMAT,
            purchased_at: purchased_at,
            register_number: register_match&.[](:register),
            ticket_number: register_match&.[](:ticket),
            cashier_code: cashier_code,
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
            handle_section_markers(line, state)
            next if skip_line?(line, state)

            parsed_line = parse_item_line(line, state)
            parsed << parsed_line if parsed_line
          end
        end

        def handle_section_markers(line, state)
          case line
          when /Début Selfscan/
            state.items_started = true
            state.section_label = SECTION_SELFS_CAN
          when /Fin Selfscan/
            state.section_label = nil
          when /^Articles avec Remise$/
            state.items_started = true
            state.discount_section = true
            state.section_label = SECTION_DISCOUNTS
          when /^Total\b/
            state.items_finished = true
          when /Hôte\(sse\)\s*:/
            state.items_started = true unless selfscan_receipt?
          end
        end

        def skip_line?(line, state)
          return true unless state.items_started?
          return true if state.items_finished?
          return true if line.match?(/Début Selfscan|Fin Selfscan|^Articles avec Remise$/)
          return true if line.match?(/\A(?:TOTAL REMISES|TVAS|Brut|Montant total des remises|Reçu |TOT\. |VOTRE COMPTE)/)
          return true if line.start_with?("(", ">")

          false
        end

        def parse_item_line(line, state)
          match = line.match(ITEM_LINE_PATTERN)
          return unless match

          line_details = line_details(match, state)
          return unless line_details

          {
            raw_text: line,
            label: line_details.fetch(:label),
            label_truncated: line_details.fetch(:label_truncated),
            quantity: line_details.fetch(:quantity),
            unit_of_measure: "piece",
            unit_price_cents: line_details.fetch(:unit_price_cents),
            total_cents: line_details.fetch(:total_cents),
            vat_rate_bp: nil,
            tr_eligible: match[:tr_marker].present?,
            section_label: state.section_label,
            kind: line_details.fetch(:kind)
          }
        end

        def line_details(match, state)
          total_cents = cents_from(match[:total])
          label = match[:label].strip
          label, truncated = normalize_label(label)
          quantity = decimal_from(match[:quantity]) || BigDecimal("1")
          unit_price_cents = cents_from(match[:unit_price])
          kind = total_cents.negative? ? "discount" : "item"
          total_cents = quantity_total_cents(quantity, unit_price_cents) if state.discount_section? && unit_price_cents

          return if skip_discount_annotation?(kind, label)

          {
            label: label,
            label_truncated: truncated,
            quantity: quantity,
            unit_price_cents: unit_price_cents,
            total_cents: total_cents,
            kind: kind
          }
        end

        def skip_discount_annotation?(kind, label)
          kind == "discount" && label == "TOTAL REMISES"
        end

        def quantity_total_cents(quantity, unit_price_cents)
          (quantity * unit_price_cents).round
        end

        def payment_attributes
          text_lines.filter_map.with_index(1) do |line, index|
            match = line.match(/\AReçu (?<raw_label>.+?)\s+(?<amount>\d+,\d{2})\z/)
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
          case raw_label
          when /CARTE BANCAIRE/
            "bank_card"
          when /ESPECES/
            "cash"
          else
            "other"
          end
        end

        def add_scan_warnings
          scan_warning_lines.each do |line|
            add_warning(
              code: "auchan_selfscan_warning",
              detail: line
            )
          end
        end

        def parsed_status(validator_results)
          validator_results.all? && severe_scan_warning_lines.empty? ? "parsed" : "needs_review"
        end

        def severe_scan_warning_lines
          scan_warning_lines.grep(/incorrect/i)
        end

        def scan_warning_lines
          @scan_warning_lines ||= text_lines.grep(/Lecture partielle|Nouveau scan/i)
        end

        def purchased_at
          match = text_lines.lazy.filter_map { |line| line.match(DATE_PATTERN) }.first
          return unless match

          Time.zone.local(
            match[:year].to_i,
            french_month_number(match[:month]),
            match[:day].to_i,
            match[:hour].to_i,
            match[:minute].to_i,
            match[:second].to_i
          )
        end

        def register_match
          @register_match ||= text_lines.lazy.filter_map { |line| line.match(REGISTER_PATTERN) }.first
        end

        def cashier_code
          text_lines.lazy.filter_map { |line| line[/\AHôte\(sse\)\s*:\s*(\S+)/, 1] }.first
        end

        def total_cents
          total_line = text_lines.find { |line| line.match?(/\ATotal \d+,\d{2} €\z/) }
          cents_from(total_line[/\d+,\d{2}/]) if total_line
        end

        def declared_article_count
          article_count_line = text_lines.find { |line| line.match?(/\A\d+ Articles\z/) }
          article_count_line.to_i if article_count_line
        end

        def normalize_label(label)
          truncated = label.match?(/\s*\.\.\z/)
          label = label.sub(/\s*\.\.\z/, "").strip

          [ label, truncated ]
        end

        def cents_from(amount)
          return unless amount

          sign = amount.start_with?("-") ? -1 : 1
          euros, cents = amount.delete_prefix("-").split(",")
          sign * ((euros.to_i * 100) + cents.to_i)
        end

        def decimal_from(value)
          return unless value

          BigDecimal(value.tr(",", "."))
        end

        def selfscan_receipt?
          text_lines.any? { |line| line.match?(/Début Selfscan/) }
        end

        def text_lines
          @text_lines ||= text.lines.map(&:strip).reject(&:blank?)
        end

        class LineState
          attr_accessor :section_label

          def initialize
            @items_started = false
            @items_finished = false
            @discount_section = false
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

          def discount_section?
            @discount_section
          end

          def discount_section=(value)
            @discount_section = value
          end
        end
      end
    end
  end
end
