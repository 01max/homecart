module Parser
  module Leclerc
    module Web
      class V1 < Parser::Base
        FORMAT = Parser::Registry::FORMATS.fetch(:leclerc_web_v1)

        DATE_PATTERN = /\ACaisse(?: Drive)? \S+ - (?<day>\d{1,2}) (?<month>\p{L}+\.?) (?<year>\d{4})\z/
        LINE_PATTERN = /\A(?<label>.+?)\s+(?<amount>\d+\.\d{2})\z/
        TOTAL_PATTERN = /\ATotal (?<count>\d+) articles?\s+(?<amount>\d+\.\d{2})\z/
        PAYMENT_PATTERN = /\A(?<raw_label>CB Web .+?)\s+(?<amount>\d+\.\d{2})\z/

        Parser::Registry.register(FORMAT, self)

        private

        def receipt_attributes
          {
            parser_format: FORMAT,
            purchased_at: purchased_at,
            register_number: nil,
            ticket_number: nil,
            cashier_code: nil,
            total_cents: total_cents,
            declared_article_count: declared_article_count,
            parser_status: "parsed",
            parser_warnings: warnings
          }
        end

        def parsed_lines
          item_lines.map { |line| parse_line(line) }
        end

        def item_lines
          @item_lines ||= text_lines.take_while { |line| !line.match?(TOTAL_PATTERN) }.select { |line| line.match?(LINE_PATTERN) }
        end

        def parse_line(line)
          match = line.match(LINE_PATTERN)
          label = match[:label].strip
          quantity, label = extract_quantity_and_label(label)

          {
            raw_text: line,
            label: normalize_label(label),
            label_truncated: label_truncated?(label),
            quantity: quantity,
            unit_of_measure: "piece",
            unit_price_cents: nil,
            total_cents: cents_from(match[:amount]),
            vat_rate_bp: fee_line?(label) ? 550 : nil,
            tr_eligible: false,
            section_label: nil,
            kind: fee_line?(label) ? "fee" : "item"
          }
        end

        def extract_quantity_and_label(label)
          match = label.match(/\A(?<quantity>\d+) X (?<label>.+)\z/)
          return [ BigDecimal("1"), label ] unless match

          [ BigDecimal(match[:quantity]), match[:label] ]
        end

        def payment_attributes
          text_lines.filter_map.with_index(1) do |line, index|
            match = line.match(PAYMENT_PATTERN)
            next unless match

            {
              position: index,
              raw_label: match[:raw_label],
              category: "web",
              amount_cents: cents_from(match[:amount])
            }
          end
        end

        def purchased_at
          match = text_lines.lazy.filter_map { |line| line.match(DATE_PATTERN) }.first
          return unless match

          Time.zone.local(match[:year].to_i, french_month_number(match[:month]), match[:day].to_i)
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

        def fee_line?(label)
          label.start_with?("FRAIS DE LIVRAISON")
        end
      end
    end
  end
end
