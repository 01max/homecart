module Parser
  module Leclerc
    module Paper
      class V2 < Base
        FORMAT = Parser::Registry::FORMATS.fetch(:leclerc_paper_v2)

        BODY_HEADER_PATTERN = /\ATTC\s+TVA\z/
        ITEM_LINE_PATTERN = /\A(?<label>.+?)\s+(?<amount>\d+\.\d{2})\s+(?<vat_code>\d+)\z/
        QUANTITY_LINE_PATTERN = /\A(?<quantity>\d+(?:[,.]\d+)?)\s+X\s+(?<unit_price>\d+\.\d{2})€\s+(?<total>\d+\.\d{2})\s+(?<vat_code>\d+)\z/
        PAYMENT_PATTERN = /\A(?<raw_label>CB|Bon achat carte|Bon immediat)\s+(?<amount>\d+\.\d{2})\z/
        VAT_ROW_PATTERN = /\A(?<code>\d+)\s+(?<rate_whole>\d+)%\s*(?<rate_decimal>\d{2})\s+[-\d.]+\s+[-\d.]+\s+[-\d.]+\z/

        Parser::Registry.register(FORMAT, self)

        private

        def body_marker?(line)
          line.match?(BODY_HEADER_PATTERN)
        end

        def implicit_items_start?(_line)
          false
        end

        def item_vat_rate_bp(match)
          vat_rate_bp_for(match[:vat_code])
        end

        def quantity_vat_rate_bp(match)
          vat_rate_bp_for(match[:vat_code])
        end

        def vat_rate_bp_for(vat_code)
          vat_rates_by_code.fetch(vat_code) do
            add_warning(
              code: "missing_vat_code",
              detail: I18n.t("receipt_ingestion.parser_warnings.missing_vat_code.detail", vat_code: vat_code)
            )
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
      end
    end
  end
end
