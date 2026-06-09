module ProductCatalog
  # Builds canonical searchable text for catalogue identities and receipt labels.
  class NormalizeTextService < ApplicationService
    def initialize(text)
      @text = text
    end

    def call
      normalized_text
        .gsub(/[^a-z0-9]+/, " ")
        .squish
    end

    private

    attr_reader :text

    def normalized_text
      ActiveSupport::Inflector.transliterate(text.to_s.unicode_normalize(:nfkc)).downcase
    end
  end
end
