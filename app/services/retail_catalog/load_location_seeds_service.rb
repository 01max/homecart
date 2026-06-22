require "yaml"

module RetailCatalog
  # Loads tracked retail seed data plus optional local-only private hints.
  class LoadLocationSeedsService < ApplicationService
    ARRAY_IDENTIFIER_KEYS = %w[
      receipt_header_patterns
      receipt_store_codes
      legal_entities
    ].freeze

    OBJECT_IDENTIFIER_KEYS = %w[
      detection_hints
      private_detection_hints
    ].freeze

    def initialize(default_path:, local_path: nil)
      @default_path = default_path
      @local_path = local_path
    end

    def call
      brands_by_slug = seed_data.fetch("brands").each_with_object({}) do |attributes, collection|
        brand = RetailBrand.find_or_initialize_by(slug: attributes.fetch("slug"))
        brand.update!(
          name: attributes.fetch("name"),
          aliases: attributes.fetch("aliases", [])
        )
        collection[brand.slug] = brand
      end

      seed_data.fetch("stores").each do |attributes|
        brand = brands_by_slug.fetch(attributes.fetch("brand_slug"))
        store = Store.find_or_initialize_by(
          retail_brand: brand,
          location_name: attributes.fetch("location_name"),
          channel: attributes.fetch("channel")
        )

        store.update!(
          address: attributes["address"],
          identifiers: attributes.fetch("identifiers", {})
        )
      end
    end

    private

    attr_reader :default_path, :local_path

    def seed_data
      @seed_data ||= merge_seed_data(load_seed_data(default_path), load_local_seed_data)
    end

    def load_local_seed_data
      return empty_seed_data if local_path.blank? || !File.exist?(local_path)

      load_seed_data(local_path)
    end

    def load_seed_data(path)
      data = YAML.safe_load_file(path, aliases: false) || {}

      {
        "brands" => Array(data["brands"]).map { |attributes| stringify_hash(attributes) },
        "stores" => Array(data["stores"]).map { |attributes| normalize_store_attributes(attributes) }
      }
    end

    def empty_seed_data
      { "brands" => [], "stores" => [] }
    end

    def merge_seed_data(default_data, local_data)
      {
        "brands" => merge_records(
          default_data.fetch("brands"),
          local_data.fetch("brands"),
          key: ->(attributes) { attributes.fetch("slug") },
          merge: ->(tracked, local) { merge_brand_attributes(tracked, local) }
        ),
        "stores" => merge_records(
          default_data.fetch("stores"),
          local_data.fetch("stores"),
          key: ->(attributes) { store_key(attributes) },
          merge: ->(tracked, local) { merge_store_attributes(tracked, local) }
        )
      }
    end

    def merge_records(default_records, local_records, key:, merge:)
      records_by_key = {}
      keys = []

      default_records.each do |record|
        record_key = key.call(record)
        keys << record_key
        records_by_key[record_key] = record
      end

      local_records.each do |record|
        record_key = key.call(record)
        keys << record_key unless records_by_key.key?(record_key)
        records_by_key[record_key] = records_by_key.key?(record_key) ? merge.call(records_by_key.fetch(record_key), record) : record
      end

      keys.map { |record_key| records_by_key.fetch(record_key) }
    end

    def merge_brand_attributes(tracked, local)
      tracked.merge(local).tap do |attributes|
        attributes["aliases"] = merge_arrays(tracked["aliases"], local["aliases"])
      end
    end

    def merge_store_attributes(tracked, local)
      tracked.merge(local).tap do |attributes|
        attributes["identifiers"] = normalize_identifiers(
          deep_merge_identifiers(tracked.fetch("identifiers", {}), local.fetch("identifiers", {}))
        )
      end
    end

    def store_key(attributes)
      [
        attributes.fetch("brand_slug"),
        attributes.fetch("location_name"),
        attributes.fetch("channel")
      ]
    end

    def normalize_store_attributes(attributes)
      stringify_hash(attributes).tap do |store_attributes|
        store_attributes["identifiers"] = normalize_identifiers(store_attributes.fetch("identifiers", {}))
      end
    end

    def normalize_identifiers(identifiers)
      stringify_hash(identifiers).tap do |normalized|
        ARRAY_IDENTIFIER_KEYS.each do |key|
          next unless normalized.key?(key)

          normalized[key] = normalize_array_identifier(key, normalized.fetch(key))
        end

        OBJECT_IDENTIFIER_KEYS.each do |key|
          next unless normalized.key?(key)

          normalized[key] = normalize_object_identifier(key, normalized.fetch(key))
        end

        validate_default_parser_format(normalized["default_parser_format"]) if normalized.key?("default_parser_format")
      end
    end

    def normalize_array_identifier(key, value)
      return [ value ] if value.is_a?(String)
      return value.compact if value.is_a?(Array)

      raise ArgumentError, "Store identifier #{key} must be an array"
    end

    def normalize_object_identifier(key, value)
      return stringify_hash(value) if value.is_a?(Hash)

      raise ArgumentError, "Store identifier #{key} must be an object"
    end

    def validate_default_parser_format(value)
      return if value.blank? || SourceDocument::PARSER_FORMATS.value?(value)

      raise ArgumentError, "Store identifier default_parser_format must be a registered parser format"
    end

    def deep_merge_identifiers(tracked, local)
      tracked.merge(local) do |_key, tracked_value, local_value|
        if tracked_value.is_a?(Hash) && local_value.is_a?(Hash)
          deep_merge_identifiers(stringify_hash(tracked_value), stringify_hash(local_value))
        elsif tracked_value.is_a?(Array) && local_value.is_a?(Array)
          merge_arrays(tracked_value, local_value)
        else
          local_value
        end
      end
    end

    def merge_arrays(first, second)
      Array(first) | Array(second)
    end

    def stringify_hash(hash)
      hash.to_h.each_with_object({}) do |(key, value), collection|
        collection[key.to_s] = value.is_a?(Hash) ? stringify_hash(value) : value
      end
    end
  end
end
