require "bigdecimal"

module Parser
  module Auchan
    module Invoice
      # Parser for generated Auchan invoice PDF text extracted with layout.
      class V1 < Parser::Base
        FORMAT = Parser::Registry::FORMATS.fetch(:auchan_invoice_v1)
        DATE_PATTERN = /\A(?<day>\d{2})\/(?<month>\d{2})\/(?<year>\d{4})\z/
        PRODUCT_ROW_PATTERN = /\A(?<source_reference>\d{13})\s+(?<rest>.+)\z/
        ECO_PARTICIPATION_ROW_PATTERN = /\AEco-participation\s*:\s+(?<rest>.+)\z/
        PAYMENT_ROW_PATTERN = /\A(?<raw_label>[[:upper:]ÉÈÀÙÇ0-9 '\-]+?)\s+(?<amount>\d+,\d{2})\z/
        SUMMARY_TOTAL_PATTERN = /\A(?<label>Total à payer) \(€\)\s+(?<amount>\d+,\d{2})\z/
        VAT_SUMMARY_PATTERN = /\A(?<rate>\d+,\d{2})\s+\d+,\d{2}\s+\d+,\d{2}\s+\d+,\d{2}\z/
        FALLBACK_VAT_RATES = %w[2,10 5,50 10,00 20,00].freeze

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
            declared_article_count: nil,
            parser_status: "parsed",
            parser_warnings: warnings
          }
        end

        def parsed_lines
          @parsed_lines ||= text_lines.each_with_index.filter_map do |line, index|
            product_line_attributes(line, index) || eco_participation_line_attributes(line)
          end
        end

        def product_line_attributes(line, index)
          match = line.match(PRODUCT_ROW_PATTERN)
          return unless match

          row = parsed_product_row(match)
          {
            raw_text: product_raw_text(line, index),
            source_reference: match[:source_reference],
            label: row.fetch(:label),
            label_truncated: false,
            quantity: row.fetch(:quantity),
            unit_of_measure: "piece",
            unit_price_cents: unit_price_cents(row.fetch(:total_cents), row.fetch(:quantity)),
            total_cents: row.fetch(:total_cents),
            vat_rate_bp: row.fetch(:vat_rate_bp),
            tr_eligible: false,
            section_label: nil,
            kind: "item"
          }
        end

        def parsed_product_row(match)
          columns = split_columns(match[:rest])
          vat_index = vat_column_index(columns)
          {
            label: columns.first,
            quantity: quantity_from(columns),
            total_cents: cents_from(columns.last),
            vat_rate_bp: vat_rate_bp_from(vat_index ? columns[vat_index] : nil),
            waaoh_cents: waaoh_cents_from(columns, vat_index)
          }
        end

        def product_raw_text(line, index)
          note = text_lines[index + 1]
          return line unless non_billable_note?(note)

          "#{line}\n#{note}"
        end

        def non_billable_note?(line)
          line.to_s.match?(/\AProduit non facturable\z/)
        end

        def eco_participation_line_attributes(line)
          match = line.match(ECO_PARTICIPATION_ROW_PATTERN)
          return unless match

          amount_cents = cents_from(split_columns(match[:rest]).last)
          {
            raw_text: line,
            source_reference: nil,
            label: "Eco-participation",
            label_truncated: false,
            quantity: BigDecimal("1"),
            unit_of_measure: "piece",
            unit_price_cents: amount_cents,
            total_cents: amount_cents,
            vat_rate_bp: nil,
            tr_eligible: false,
            section_label: nil,
            kind: "fee"
          }
        end

        def promotion_attributes
          line_level_waaoh_promotions + waaoh_debit_promotions
        end

        def line_level_waaoh_promotions
          line_attributes.filter_map do |line|
            row = product_rows_by_reference[line.fetch(:source_reference)]
            next unless row&.fetch(:waaoh_cents)

            promotion_attributes_for(
              program: "auchan_waaoh",
              unit: "euro_cents",
              delta: row.fetch(:waaoh_cents),
              label: line.fetch(:label),
              kind: "loyalty_cash_credit",
              linked_line_position: line.fetch(:position)
            )
          end
        end

        def waaoh_debit_promotions
          payment_rows.select { |payment| payment.fetch(:raw_label) == "WAAOH" }.map do |payment|
            promotion_attributes_for(
              program: "auchan_waaoh",
              unit: "euro_cents",
              delta: -payment.fetch(:amount_cents),
              label: payment.fetch(:raw_label),
              kind: "loyalty_cash_debit"
            )
          end
        end

        def payment_attributes
          payment_rows.map.with_index(1) do |payment, position|
            payment.merge(position: position)
          end
        end

        def payment_rows
          @payment_rows ||= begin
            in_payment_section = false
            text_lines.filter_map do |line|
              if line.start_with?("Mode de paiement")
                in_payment_section = true
                next
              end
              in_payment_section = false if line.start_with?("Total ")
              next unless in_payment_section

              payment_row(line)
            end
          end
        end

        def payment_row(line)
          match = line.match(PAYMENT_ROW_PATTERN)
          return unless match

          {
            raw_label: match[:raw_label].strip,
            category: payment_category(match[:raw_label]),
            amount_cents: cents_from(match[:amount])
          }
        end

        def purchased_at
          match = date_after("Date de commande :")&.match(DATE_PATTERN)
          return unless match

          Time.zone.local(match[:year].to_i, match[:month].to_i, match[:day].to_i)
        end

        def date_after(label)
          index = text_lines.index(label)
          text_lines[index + 1] if index
        end

        def total_cents
          match = text_lines.lazy.filter_map { |line| line.match(SUMMARY_TOTAL_PATTERN) }.first
          cents_from(match[:amount]) if match
        end

        def product_rows_by_reference
          @product_rows_by_reference ||= text_lines.each_with_object({}) do |line, rows|
            match = line.match(PRODUCT_ROW_PATTERN)
            next unless match

            rows[match[:source_reference]] = parsed_product_row(match)
          end
        end

        def split_columns(text)
          text.strip.split(/\s{2,}/)
        end

        def quantity_from(columns)
          quantity_text = columns.find { |column| quantity_column?(column) }
          decimal_from(quantity_text) || BigDecimal("1")
        end

        def quantity_column?(column)
          column.match?(/\A\d+(?:,\d)?\z/)
        end

        def unit_price_cents(total_cents, quantity)
          return if quantity.zero?

          unit_price = BigDecimal(total_cents.to_s) / quantity
          unit_price.to_i if unit_price == unit_price.to_i
        end

        def vat_column_index(columns)
          columns.rindex { |column| vat_rate_texts.include?(column) }
        end

        def vat_rate_texts
          @vat_rate_texts ||= begin
            rates = text_lines.filter_map { |line| line[VAT_SUMMARY_PATTERN, :rate] }
            rates.presence || FALLBACK_VAT_RATES
          end
        end

        def vat_rate_bp_from(rate)
          return unless rate

          (decimal_from(rate) * 100).to_i
        end

        def waaoh_cents_from(columns, vat_index)
          return unless vat_index

          waaoh_text = columns[vat_index + 1]
          return unless waaoh_text
          return if waaoh_text == columns.last

          cents_from(waaoh_text)
        end
      end
    end
  end
end
