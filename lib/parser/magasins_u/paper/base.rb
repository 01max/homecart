module Parser
  module MagasinsU
    module Paper
      class Base < Parser::Base
        private

        def receipt_attributes
          {
            parser_format: self.class::FORMAT,
            purchased_at: purchased_at,
            register_number: register_number,
            ticket_number: ticket_number,
            cashier_code: cashier_code,
            total_cents: total_cents,
            declared_article_count: declared_article_count,
            parser_status: "parsed",
            parser_warnings: warnings
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

        def payment_category(raw_label)
          return "tickets_restaurant" if raw_label.start_with?("CB TRD")
          return "bank_card" if raw_label.start_with?("CB")

          "other"
        end

        def total_cents
          cents_from(total_match&.[](:amount))
        end

        def declared_article_count
          total_match&.[](:count)&.to_i
        end

        def total_match
          @total_match ||= text_lines.lazy.filter_map { |line| line.match(self.class::TOTAL_PATTERN) }.first
        end

        def vat_rate_bp_for(vat_code)
          vat_rates_by_code.fetch(vat_code) do
            add_warning(code: "missing_vat_code", detail: "No VAT table row found for code #{vat_code}")
            nil
          end
        end

        def vat_rates_by_code
          @vat_rates_by_code ||= text_lines.filter_map do |line|
            match = line.match(self.class::VAT_ROW_PATTERN)
            next unless match

            [ match[:code], (decimal_from(match[:rate]) * 100).to_i ]
          end.to_h
        end

        def clean_label(label)
          label.strip
        end
      end
    end
  end
end
