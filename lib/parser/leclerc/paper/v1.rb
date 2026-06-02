module Parser
  module Leclerc
    module Paper
      class V1 < Base
        FORMAT = Parser::Registry::FORMATS.fetch(:leclerc_paper_v1)

        ITEM_LINE_PATTERN = /\A(?<label>.+?)\s+(?<amount>\d+\.\d{2})\z/
        QUANTITY_LINE_PATTERN = /\A(?<quantity>\d+(?:[,.]\d+)?)\s+X\s+(?<unit_price>\d+\.\d{2})€\s+(?<total>\d+\.\d{2})\z/
        PAYMENT_PATTERN = /\A(?<raw_label>CB|Bon achat carte)\s+(?<amount>\d+\.\d{2})\z/

        Parser::Registry.register(FORMAT, self)
      end
    end
  end
end
