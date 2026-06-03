module Parser
  module MagasinsU
    module Paper
      # Parser for pre-OmniPOS Magasins U paper receipts with chevron sections.
      class V1 < Base
        FORMAT = Parser::Registry::FORMATS.fetch(:u_paper_v1)

        HEADER_PATTERN = /\A(?<operator>\d+\s+\S+)\s+(?<day>\d{2})\/(?<month>\d{2})\/(?<year>\d{2})\s+(?<hour>\d{2}):(?<minute>\d{2})\s+(?<register>\d+)\s+(?<ticket>\d+)\z/
        SECTION_PATTERN = /\A>>>>\s+(?<section>.+)\z/
        ITEM_LINE_PATTERN = /\A(?<label>.+?)\s+(?<total>\d+,\d{2})\s€\s+(?<vat_code>\d+)\z/
        VAT_ONLY_ITEM_LINE_PATTERN = /\A(?<label>.+?)\s+(?<vat_code>\d+)\z/
        QUANTITY_LINE_PATTERN = /\A(?<quantity>\d+(?:[,.]\d+)?)\s+x\s+(?<unit_price>\d+,\d{2})\s€\s+(?<total>\d+,\d{2})\s€\s+(?<vat_code>\d+)\z/i
        WEIGHTED_QUANTITY_LINE_PATTERN = /\A(?<quantity>\d+(?:[,.]\d+)?)\s+(?<unit>kg|g|l|ml)\s+x\s+(?<unit_price>\d+,\d{2})\s€\/(?<unit_price_unit>kg|g|l|ml)\s+(?<total>\d+,\d{2})\s€\z/i
        TOTAL_PATTERN = /\ATOTAL\s+(?<count>\d+)\s+Article\(s\)\s+(?<amount>\d+,\d{2})\s€\z/
        PAYMENT_PATTERN = /\A(?<raw_label>CB .+?|ESP[EÈ]CES)\s+(?:EUR\s+)?(?<amount>\d+,\d{2})\s€\z/
        VAT_ROW_PATTERN = /\A(?<code>\d+)\s+(?:\/\s+)?(?<rate>\d+,\d{2})\s+[-\d,]+\s€\s+[-\d,]+\s€\s+[-\d,]+\s€\z/

        Parser::Registry.register(FORMAT, self)

        private

        def parsed_lines
          @parsed_lines ||= parse_receipt_lines
        end

        def parse_receipt_lines
          state = LineState.new
          text_lines.each_with_object([]) do |line, parsed|
            handle_section_marker(line, state)
            next if skip_line?(line, state)

            parse_receipt_line(line, state, parsed)
          end
        end

        def handle_section_marker(line, state)
          section_match = line.match(SECTION_PATTERN)
          return unless section_match

          state.items_started = true
          state.section_label = section_match[:section]
          clear_pending_item(state)
        end

        def skip_line?(line, state)
          return true if line.match?(SECTION_PATTERN)
          return true if state.items_finished?
          return true unless state.items_started?

          return state.items_finished = true if line.match?(/\A=+\z/) || line.match?(TOTAL_PATTERN)

          false
        end

        def parse_receipt_line(line, state, parsed)
          if (quantity_match = line.match(QUANTITY_LINE_PATTERN))
            parsed << parse_quantity_line(quantity_match, state)
            return clear_pending_item(state)
          end

          if (weighted_quantity_match = line.match(WEIGHTED_QUANTITY_LINE_PATTERN))
            parsed << parse_weighted_quantity_line(weighted_quantity_match, state)
            return clear_pending_item(state)
          end

          if (item_match = line.match(ITEM_LINE_PATTERN))
            parsed << parse_item_line(item_match, line, state)
            return clear_pending_item(state)
          end

          pending_item_match = line.match(VAT_ONLY_ITEM_LINE_PATTERN)
          unless pending_item_match
            state.pending_label = clean_label(line)
            state.pending_vat_code = nil
            return
          end

          state.pending_label = clean_label(pending_item_match[:label])
          state.pending_vat_code = pending_item_match[:vat_code]
        end

        def parse_item_line(match, raw_text, state)
          label = clean_label(match[:label])

          item_attributes(
            raw_text: raw_text,
            label: label,
            quantity: BigDecimal("1"),
            unit_price_cents: nil,
            total_cents: cents_from(match[:total]),
            vat_rate_bp: vat_rate_bp_for(match[:vat_code]),
            section_label: state.section_label
          )
        end

        def parse_quantity_line(match, state)
          label = state.pending_label

          item_attributes(
            raw_text: [ label, match.to_s ].join("\n"),
            label: label,
            quantity: decimal_from(match[:quantity]),
            unit_price_cents: cents_from(match[:unit_price]),
            total_cents: cents_from(match[:total]),
            vat_rate_bp: vat_rate_bp_for(match[:vat_code]),
            section_label: state.section_label
          )
        end

        def parse_weighted_quantity_line(match, state)
          label = state.pending_label

          item_attributes(
            raw_text: [ label_with_vat_code(state), match.to_s ].join("\n"),
            label: label,
            quantity: decimal_from(match[:quantity]),
            unit_of_measure: match[:unit].downcase,
            unit_price_cents: cents_from(match[:unit_price]),
            total_cents: cents_from(match[:total]),
            vat_rate_bp: vat_rate_bp_for(state.pending_vat_code),
            section_label: state.section_label
          )
        end

        def item_attributes(raw_text:, label:, quantity:, total_cents:, vat_rate_bp:, section_label:, unit_price_cents:, unit_of_measure: "piece")
          {
            raw_text: raw_text,
            label: normalize_label(label),
            label_truncated: label_truncated?(label),
            quantity: quantity,
            unit_of_measure: unit_of_measure,
            unit_price_cents: unit_price_cents,
            total_cents: total_cents,
            vat_rate_bp: vat_rate_bp,
            tr_eligible: false,
            section_label: section_label,
            kind: "item"
          }
        end

        def purchased_at
          return unless header_match

          Time.zone.local(
            "20#{header_match[:year]}".to_i,
            header_match[:month].to_i,
            header_match[:day].to_i,
            header_match[:hour].to_i,
            header_match[:minute].to_i
          )
        end

        def register_number
          header_match&.[](:register)
        end

        def ticket_number
          header_match&.[](:ticket)
        end

        def cashier_code
          header_match&.[](:operator)
        end

        def header_match
          @header_match ||= text_lines.lazy.filter_map { |line| line.match(HEADER_PATTERN) }.first
        end

        def clear_pending_item(state)
          state.pending_label = nil
          state.pending_vat_code = nil
        end

        def label_with_vat_code(state)
          [ state.pending_label, state.pending_vat_code ].compact.join(" ")
        end

        class LineState
          attr_accessor :section_label, :pending_label, :pending_vat_code

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
