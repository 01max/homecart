module Parser
  module MagasinsU
    module Paper
      # Shared Magasins U parser helpers, including Carte U balance promotions.
      class Base < Parser::Base
        CARTE_U_BEFORE_PATTERN = /\ACarte U\s+solde\s+avant\b.*?(?<amount>\d+,\d{2})\s€?\z/i
        CARTE_U_AFTER_PATTERN = /\ACarte U\s+solde\s+apr[eè]s\b.*?(?<amount>\d+,\d{2})\s€?\z/i
        VIGNETTE_ACCRUAL_PATTERN = /\A(?<count>\d+)\s+vignette\(s\)\s+(?<campaign>.+?)\s+offertes?(?:\(s\))?\z/i

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

        def promotion_attributes
          carte_u_promotions + vignette_promotions
        end

        def carte_u_promotions
          carte_u_balance_delta.map do |delta|
            promotion_attributes_for(
              program: "u_carte_u",
              unit: "euro_cents",
              delta: delta,
              label: "Carte U solde",
              kind: delta.positive? ? "loyalty_cash_credit" : "loyalty_cash_debit"
            )
          end
        end

        def vignette_promotions
          text_lines.filter_map do |line|
            match = line.match(VIGNETTE_ACCRUAL_PATTERN)
            next unless match

            campaign = normalize_label(match[:campaign])
            promotion_attributes_for(
              program: vignette_program(campaign),
              unit: "vignette_count",
              delta: match[:count].to_i,
              label: campaign,
              kind: "points_accrual"
            )
          end
        end

        def carte_u_balance_delta
          return [] unless carte_u_before_cents && carte_u_after_cents

          delta = carte_u_after_cents - carte_u_before_cents
          delta.zero? ? [] : [ delta ]
        end

        def carte_u_before_cents
          @carte_u_before_cents ||= cents_from(carte_u_match(CARTE_U_BEFORE_PATTERN)&.[](:amount))
        end

        def carte_u_after_cents
          @carte_u_after_cents ||= cents_from(carte_u_match(CARTE_U_AFTER_PATTERN)&.[](:amount))
        end

        def carte_u_match(pattern)
          text_lines.lazy.filter_map { |line| line.match(pattern) }.first
        end

        def vignette_program(campaign)
          case campaign.to_s
          when /\AJBL\z/i
            "u_vignettes_jbl"
          else
            "u_vignettes"
          end
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
            add_warning(
              code: "missing_vat_code",
              detail: I18n.t("receipt_ingestion.parser_warnings.missing_vat_code.detail", vat_code: vat_code)
            )
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
