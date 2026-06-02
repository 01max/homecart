module Parser
  module FrenchDates
    MONTH_ALIASES_BY_NUMBER = {
      1 => %w[ janvier janv ],
      2 => %w[ février févr ],
      3 => %w[ mars ],
      4 => %w[ avril avr ],
      5 => %w[ mai ],
      6 => %w[ juin ],
      7 => %w[ juillet juil ],
      8 => %w[ août ],
      9 => %w[ septembre sept ],
      10 => %w[ octobre oct ],
      11 => %w[ novembre nov ],
      12 => %w[ décembre déc ]
    }.freeze

    MONTH_NUMBERS = MONTH_ALIASES_BY_NUMBER.flat_map do |number, aliases|
      aliases.map { |month| [ month, number ] }
    end.to_h.freeze

    class << self
      def month_number(month)
        MONTH_NUMBERS.fetch(normalize_month(month))
      end

      private

      def normalize_month(month)
        month.downcase.delete_suffix(".")
      end
    end
  end
end
