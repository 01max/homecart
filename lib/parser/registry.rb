module Parser
  module Registry
    FORMATS = {
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
      def register(format, klass)
        format = normalize_format(format)
        validate_format!(format)
        validate_parser_namespace!(format, klass)

        existing_parser = registry[format]
        return klass if existing_parser == klass
        raise RegistrationError, "parser already registered for #{format}" if existing_parser

        registry[format] = klass
      end

      def for(format)
        format = normalize_format(format)

        registry.fetch(format) do
          raise UnknownFormatError, "no parser registered for #{format}"
        end
      end

      def formats
        FORMATS.values
      end

      private

      def registry
        @registry ||= {}
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
