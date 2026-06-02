module Parser
  module Leclerc
    module Paper
      class Base < Parser::Base
        HEADER_PATTERN = /\ACaisse (?<register>\S+) (?<day>\d{2}) (?<month>\p{L}+) (?<year>\d{4}) (?<hour>\d{2}):(?<minute>\d{2})\z/
        TICKET_PATTERN = /\A(?:Ticket )?\d{2}\/\d{2}\/\d{2}\s+\d+\s+(?<ticket>.+)\z/
        SECTION_PATTERN = /\A>>\s+(?<section>.+)\z/
        TOTAL_PATTERN = /\ATotal (?<count>\d+) articles?\s+(?<amount>\d+\.\d{2})\z/
        BON_ACHAT_PATTERN = /\ABon achat carte\s+(?<amount>\d+\.\d{2})\z/
        TICKET_CUMUL_PATTERN = /\ACUMUL DISPONIBLE\b/i
        VIGNETTE_PATTERN = /\A(?:Vous venez d'obtenir|Vous avez obtenu)\s+(?<count>\d+)\s+Vignette\(s\)(?:\s+(?<campaign>.+))?\z/i

        private

        def receipt_attributes
          {
            parser_format: self.class::FORMAT,
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
          return unless body_marker?(line)

          state.items_started = true
        end

        def handle_section_marker(line, state)
          section_match = line.match(SECTION_PATTERN)
          return unless section_match

          state.items_started = true
          state.section_label = section_match[:section]
        end

        def skip_line?(line, state)
          return true if body_marker?(line) || line.match?(SECTION_PATTERN)
          return true if state.items_finished?
          return true unless state.items_started? || implicit_items_start?(line)

          state.items_started = true
          return state.items_finished = true if line.match?(TOTAL_PATTERN)

          false
        end

        def parse_receipt_line(line, state, parsed)
          if (quantity_match = line.match(self.class::QUANTITY_LINE_PATTERN))
            parsed << parse_quantity_line(quantity_match, state)
            return state.pending_label = nil
          end

          item_match = line.match(self.class::ITEM_LINE_PATTERN)
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
            vat_rate_bp: item_vat_rate_bp(match),
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
            vat_rate_bp: quantity_vat_rate_bp(match),
            tr_eligible: false,
            section_label: state.section_label,
            kind: "item"
          }
        end

        def payment_attributes
          text_lines.filter_map.with_index(1) do |line, index|
            match = line.match(self.class::PAYMENT_PATTERN)
            next unless match

            {
              position: index,
              raw_label: match[:raw_label],
              category: payment_category(match[:raw_label]),
              amount_cents: cents_from(match[:amount])
            }
          end
        end

        def promotion_attributes
          bon_achat_card_promotions + ticket_cumul_promotions + vignette_promotions
        end

        def bon_achat_card_promotions
          bon_achat_amounts.map do |amount_cents|
            promotion_attributes_for(
              program: "leclerc_bon_achat_carte",
              unit: "euro_cents",
              delta: -amount_cents,
              label: "Bon achat carte",
              kind: "coupon"
            )
          end
        end

        def ticket_cumul_promotions
          return [] unless text_lines.any? { |line| line.match?(TICKET_CUMUL_PATTERN) }

          bon_achat_amounts.map do |amount_cents|
            promotion_attributes_for(
              program: "leclerc_tickets",
              unit: "euro_cents",
              delta: -amount_cents,
              label: "CUMUL DISPONIBLE",
              kind: "coupon"
            )
          end
        end

        def vignette_promotions
          text_lines.filter_map do |line|
            match = line.match(VIGNETTE_PATTERN)
            next unless match

            promotion_attributes_for(
              program: vignette_program(match[:campaign]),
              unit: "vignette_count",
              delta: match[:count].to_i,
              label: match[:campaign].presence || "Vignette(s)",
              kind: "points_accrual"
            )
          end
        end

        def bon_achat_amounts
          @bon_achat_amounts ||= text_lines.filter_map do |line|
            match = line.match(BON_ACHAT_PATTERN)
            cents_from(match[:amount]) if match
          end
        end

        def vignette_program(campaign)
          case campaign.to_s
          when /SMEG/i
            "leclerc_vignettes_smeg"
          when /ROYAL|VKB/i
            "leclerc_vignettes_royal_vkb"
          else
            "leclerc_vignettes"
          end
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

        def body_marker?(_line)
          false
        end

        def implicit_items_start?(line)
          line.match?(self.class::ITEM_LINE_PATTERN)
        end

        def item_vat_rate_bp(_match) = nil

        def quantity_vat_rate_bp(_match) = nil

        def clean_label(label)
          label.delete_prefix("*").strip
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
