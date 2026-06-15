module Parser
  module Leclerc
    module Paper
      # Shared grammar and loyalty handling for Leclerc paper receipt parsers.
      class Base < Parser::Base
        HEADER_PATTERN = /\ACaisse (?<register>\S+) (?<day>\d{2}) (?<month>\p{L}+) (?<year>\d{4}) (?<hour>\d{2}):(?<minute>\d{2})\z/
        TICKET_PATTERN = /\A(?:Ticket )?\d{2}\/\d{2}\/\d{2}\s+\d+\s+(?<ticket>.+)\z/
        SECTION_PATTERN = /\A>>\s+(?<section>.+)\z/
        TOTAL_PATTERN = /\ATotal (?<count>\d+) articles?\s+(?<amount>\d+\.\d{2})\z/
        SECTION_SEPARATOR_PATTERN = /\A-+\z/
        REMISES_SECTION_PATTERN = /\AREMISES\z/
        BONS_REDUCTION_SECTION_PATTERN = /\ABONS DE REDUCTION\z/
        DETAIL_TOTAL_PATTERN = /\ATotal\b/
        BON_ACHAT_PATTERN = /\ABon achat carte\s+(?<amount>\d+\.\d{2})\z/
        TICKET_CUMUL_PATTERN = /\ACUMUL DISPONIBLE\z/i
        VIGNETTE_ACCRUAL_PATTERN = /\A(?:Vous venez d'obtenir|Vous avez obtenu)\s*:?\s*(?<count>\d+)\s+Vignette\(s\)(?:\s+(?<campaign>.+))?\z/i
        VIGNETTE_CONSUMPTION_PATTERN = /\A(?:Vous venez d'utiliser|Vous avez utilisé)\s*:?\s*(?<count>\d+)\s+Vignette\(s\)(?:\s+(?<campaign>.+))?\z/i
        VIGNETTE_SECTION_PATTERN = /\A(?:-+\s*)?VOS VIGNETTES\s+(?<campaign>.+)\z/i

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
          body_lines = text_lines.each_with_object([]) do |line, parsed|
            handle_body_marker(line, state)
            handle_section_marker(line, state)
            next if skip_line?(line, state)

            parse_receipt_line(line, state, parsed)
          end

          body_lines + detailed_remise_discount_lines
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

          if (discount_match = line.match(discount_line_pattern))
            return state.pending_label = nil if detailed_remises_available?

            parsed << parse_discount_line(discount_match, line, state)
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

        def detailed_remise_discount_lines
          @detailed_remise_discount_lines ||= remise_detail_lines.filter_map do |line|
            match = line.match(detail_discount_line_pattern)
            next unless match
            next if match[:label].match?(DETAIL_TOTAL_PATTERN)

            discount_attributes(match, line, nil).merge(total_cents: -cents_from(match[:amount]).abs)
          end
        end

        def detailed_remises_available?
          detailed_remise_discount_lines.any?
        end

        def remise_detail_lines
          lines = []
          in_remises_section = false

          text_lines.each do |line|
            if line.match?(REMISES_SECTION_PATTERN)
              in_remises_section = true
              next
            end

            next unless in_remises_section
            break if line.match?(SECTION_SEPARATOR_PATTERN)

            lines << line
          end

          lines
        end

        def parse_discount_line(match, raw_text, state)
          discount_attributes(match, raw_text, state.section_label)
        end

        def discount_attributes(match, raw_text, section_label)
          label = clean_label(match[:label])

          {
            raw_text: raw_text,
            label: normalize_label(label),
            label_truncated: label_truncated?(label),
            quantity: BigDecimal("1"),
            unit_of_measure: "piece",
            unit_price_cents: nil,
            total_cents: cents_from(match[:amount]),
            vat_rate_bp: discount_vat_rate_bp(match),
            tr_eligible: false,
            section_label: section_label,
            kind: "discount"
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
          bon_achat_card_promotions + ticket_cumul_promotions + bon_immediat_promotions + vignette_promotions
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

        def bon_immediat_promotions
          bons_reduction_detail_lines.filter_map do |line|
            match = line.match(detail_discount_line_pattern)
            next unless match
            next if match[:label].match?(DETAIL_TOTAL_PATTERN)

            label = normalize_label(match[:label])
            promotion_attributes_for(
              program: "leclerc_bon_immediat",
              unit: "euro_cents",
              delta: -cents_from(match[:amount]).abs,
              label: label,
              kind: "immediate_discount",
              linked_line_position: linked_line_position_for(discount_link_label(label))
            )
          end
        end

        def discount_link_label(label)
          label.sub(/\s+\(X\d+\)\z/i, "")
        end

        def vignette_promotions
          vignette_accrual_promotions + vignette_consumption_promotions
        end

        def vignette_accrual_promotions
          vignette_event_promotions(
            VIGNETTE_ACCRUAL_PATTERN,
            kind: "points_accrual",
            sign: 1
          )
        end

        def vignette_consumption_promotions
          vignette_event_promotions(
            VIGNETTE_CONSUMPTION_PATTERN,
            kind: "points_consumption",
            sign: -1
          )
        end

        def vignette_event_promotions(pattern, kind:, sign:)
          text_lines.filter_map.with_index do |line, index|
            match = line.match(pattern)
            next unless match

            campaign = match[:campaign].presence || vignette_campaign_before(index)
            promotion_attributes_for(
              program: vignette_program(campaign),
              unit: "vignette_count",
              delta: sign * match[:count].to_i,
              label: campaign.presence || "Vignette(s)",
              kind: kind
            )
          end
        end

        def vignette_campaign_before(index)
          text_lines.first(index).reverse_each do |line|
            match = line.match(VIGNETTE_SECTION_PATTERN)
            return normalize_label(match[:campaign].sub(/\s*-+\z/, "")) if match
          end

          nil
        end

        def bons_reduction_detail_lines
          detail_section_lines(BONS_REDUCTION_SECTION_PATTERN)
        end

        def detail_section_lines(section_pattern)
          lines = []
          in_section = false

          text_lines.each do |line|
            if line.match?(section_pattern)
              in_section = true
              next
            end

            next unless in_section
            break if line.match?(SECTION_SEPARATOR_PATTERN)

            lines << line
          end

          lines
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
          when /MONBENTO/i
            "leclerc_vignettes_monbento"
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

        def discount_vat_rate_bp(_match) = nil

        def discount_line_pattern
          self.class.const_defined?(:DISCOUNT_LINE_PATTERN, false) ? self.class::DISCOUNT_LINE_PATTERN : /(?!)/
        end

        def detail_discount_line_pattern
          self.class.const_defined?(:DETAIL_DISCOUNT_LINE_PATTERN, false) ? self.class::DETAIL_DISCOUNT_LINE_PATTERN : /(?!)/
        end

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
