module Parser
  module MagasinsU
    module Paper
      class V2 < Base
        FORMAT = Parser::Registry::FORMATS.fetch(:u_paper_v2)

        SALE_MARKER_PATTERN = /\A\*\*\* VENTE \*\*\*\z/
        ITEM_LINE_PATTERN = /\A(?<label>.+?)\s+(?:(?<tr_marker>\(T\))\s+)?(?<total>\d+,\d{2})\s€\s+(?<vat_code>\d+)\z/
        QUANTITY_LINE_PATTERN = /\A(?<quantity>\d+(?:[,.]\d+)?)\s+x\s+(?<unit_price>\d+,\d{2})\s+EUR\z/i
        TOTAL_PATTERN = /\ATOTAL \[(?<count>\d+)\] Articles\s+(?<amount>\d+,\d{2})\s€\z/
        PAYMENT_PATTERN = /\A(?<raw_label>CB .+?)\s+(?<amount>\d+,\d{2})\s€\z/
        VAT_ROW_PATTERN = /\A(?<code>\d+)\s+(?<rate>\d+,\d{2})\s+[-\d,]+\s€\s+[-\d,]+\s€\s+[-\d,]+\s€\z/
        FOOTER_PATTERN = /\A(?<day>\d{2})\/(?<month>\d{2})\/(?<year>\d{2})\s+(?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})\s+(?<store>\d+)\s+(?<register>\d+)\s+(?<cashier>\d+)\s+(?<ticket>\d+)\z/

        Parser::Registry.register(FORMAT, self)

        private

        def parsed_lines
          @parsed_lines ||= parse_receipt_lines
        end

        def parse_receipt_lines
          state = LineState.new
          text_lines.each_with_object([]) do |line, parsed|
            handle_sale_marker(line, state)
            next if skip_line?(line, state)

            parse_receipt_line(line, state, parsed)
          end
        end

        def handle_sale_marker(line, state)
          return unless line.match?(SALE_MARKER_PATTERN)

          state.items_started = true
        end

        def skip_line?(line, state)
          return true if line.match?(SALE_MARKER_PATTERN)
          return true if state.items_finished?
          return true unless state.items_started?

          return state.items_finished = true if line.match?(/\ANombre de lignes d'article\b/) || line.match?(TOTAL_PATTERN)

          false
        end

        def parse_receipt_line(line, state, parsed)
          if (quantity_match = line.match(QUANTITY_LINE_PATTERN))
            parsed << parse_quantity_line(quantity_match, state)
            return state.pending_item = nil
          end

          if (item_match = line.match(ITEM_LINE_PATTERN))
            state.pending_item = item_attributes_from(item_match, line, state)
            return
          end

          state.section_label = line
        end

        def item_attributes_from(match, raw_text, state)
          label = clean_label(match[:label])

          {
            raw_text: raw_text,
            label: normalize_label(label),
            label_truncated: label_truncated?(label),
            total_cents: cents_from(match[:total]),
            vat_rate_bp: vat_rate_bp_for(match[:vat_code]),
            tr_eligible: match[:tr_marker].present?,
            section_label: state.section_label,
            kind: "item"
          }
        end

        def parse_quantity_line(match, state)
          pending_item = state.pending_item

          pending_item.merge(
            raw_text: [ pending_item[:raw_text], match.to_s ].join("\n"),
            quantity: decimal_from(match[:quantity]),
            unit_of_measure: "piece",
            unit_price_cents: cents_from(match[:unit_price])
          )
        end

        def purchased_at
          return unless footer_match

          Time.zone.local(
            "20#{footer_match[:year]}".to_i,
            footer_match[:month].to_i,
            footer_match[:day].to_i,
            footer_match[:hour].to_i,
            footer_match[:minute].to_i,
            footer_match[:second].to_i
          )
        end

        def register_number
          footer_match&.[](:register)
        end

        def ticket_number
          footer_match&.[](:ticket)
        end

        def cashier_code
          footer_match&.[](:cashier)
        end

        def footer_match
          @footer_match ||= text_lines.lazy.filter_map { |line| line.match(FOOTER_PATTERN) }.first
        end

        class LineState
          attr_accessor :section_label, :pending_item

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
