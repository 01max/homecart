module Parser
  # Registry mapping dotted parser format ids to parser classes.
  #
  # Format ids use the `brand.channel.version` convention and Ruby constants
  # mirror that hierarchy under the singular `Parser` namespace.
  module Registry
    FORMATS = {
      auchan_invoice_v1: "auchan.invoice.v1",
      auchan_paper_v1: "auchan.paper.v1",
      leclerc_paper_v1: "leclerc.paper.v1",
      leclerc_paper_v2: "leclerc.paper.v2",
      leclerc_web_v1: "leclerc.web.v1",
      u_paper_v1: "u.paper.v1",
      u_paper_v2: "u.paper.v2"
    }.freeze

    BRAND_CONSTANT_NAMES = {
      "u" => "MagasinsU"
    }.freeze

    FormatError = Class.new(StandardError)
    NamespaceError = Class.new(StandardError)
    RegistrationError = Class.new(StandardError)
    UnknownFormatError = Class.new(KeyError)

    class << self
      # Register a parser class for a known format id.
      #
      # @param format [String, Symbol] dotted parser format id
      # @param klass [Class] parser class whose name matches the expected namespace
      # @return [Class] registered parser class
      # @raise [FormatError] when the format id is not supported
      # @raise [NamespaceError] when class name does not mirror the format id
      # @raise [RegistrationError] when another parser is already registered
      def register(format, klass)
        format = normalize_format(format)
        validate_format!(format)
        validate_parser_namespace!(format, klass)

        existing_parser = registry[format]
        return klass if existing_parser == klass
        raise RegistrationError, "parser already registered for #{format}" if existing_parser

        registry[format] = klass
      end

      # Look up the parser class registered for a format id.
      #
      # @param format [String, Symbol] dotted parser format id
      # @return [Class] parser class
      # @raise [UnknownFormatError] when no parser has registered the format
      def for(format)
        format = normalize_format(format)
        load_parser_constant(format)

        registry.fetch(format) do
          raise UnknownFormatError, "no parser registered for #{format}"
        end
      end

      # @return [Array<String>] supported dotted parser format ids
      def formats
        FORMATS.values
      end

      private

      def registry
        @registry ||= {}
      end

      def load_parser_constant(format)
        return if registry.key?(format)

        klass = expected_parser_name(format).constantize
        register(format, klass) unless registry.key?(format)
      rescue NameError
        nil
      end

      def normalize_format(format)
        format.to_s
      end

      def validate_format!(format)
        return if formats.include?(format)

        raise FormatError, "unknown parser format: #{format}"
      end

      def validate_parser_namespace!(format, klass)
        expected_name = expected_parser_name(format)
        return if klass.name == expected_name

        raise NamespaceError, "expected #{format} to register #{expected_name}, got #{klass.name.inspect}"
      end

      def expected_parser_name(format)
        brand, channel, version = format.split(".")

        [ "Parser", brand_constant_name(brand), constant_segment(channel), version.upcase ].join("::")
      end

      def brand_constant_name(brand)
        BRAND_CONSTANT_NAMES.fetch(brand) { constant_segment(brand) }
      end

      def constant_segment(segment)
        segment.split("_").map(&:capitalize).join
      end
    end
  end
end
