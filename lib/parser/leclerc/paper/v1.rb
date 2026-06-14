module Parser
  module Leclerc
    module Paper
      # Parser for old Leclerc paper POS receipts without per-line VAT codes.
      class V1 < Base
        FORMAT = Parser::Registry::FORMATS.fetch(:leclerc_paper_v1)

        ITEM_LINE_PATTERN = /\A(?<label>.+?)\s+(?<amount>\d+\.\d{2})\z/
        DISCOUNT_LINE_PATTERN = /\A(?<label>.+?)\s+(?<amount>-\d+\.\d{2})\z/
        DETAIL_DISCOUNT_LINE_PATTERN = /\A(?<label>.+?)\s+(?<amount>\d+\.\d{2})\z/
        QUANTITY_LINE_PATTERN = /\A(?<quantity>\d+(?:[,.]\d+)?)\s+X\s+(?<unit_price>\d+\.\d{2})€\s+(?<total>\d+\.\d{2})\z/
        PAYMENT_PATTERN = /\A(?<raw_label>CB|Bon achat carte|Bon immediat)\s+(?<amount>\d+\.\d{2})\z/

        Parser::Registry.register(FORMAT, self)
      end
    end
  end
end
