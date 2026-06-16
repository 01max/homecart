require "bigdecimal"
require "set"

module Parser
  # Builds the line view used by parsers and validators.
  #
  # OCR can repeat item rows. Identical item rows represent a repeated purchase
  # and collapse into one row with a larger quantity. When one duplicate carries
  # an arithmetically inconsistent total and another carries the same quantity
  # and unit price with a reconciled total, the reconciled row wins.
  class LineCoalescer
    class << self
      def call(lines)
        new(lines).call
      end
    end

    def initialize(lines)
      @entries = lines.map.with_index { |line, index| { line: line_attributes(line), index: index } }
    end

    def call
      coalesced_group_actions.each do |action|
        merged_entry = merged_entry_for(action.fetch(:merge_entries))
        next unless merged_entry

        replacement_by_index[merged_entry.fetch(:index)] = merged_entry.fetch(:line)
        skipped_entries = action.fetch(:skip_entries) + action.fetch(:merge_entries).reject { |entry| entry == merged_entry }
        skipped_entries.each { |entry| skipped_indices << entry.fetch(:index) }
      end

      entries.filter_map do |entry|
        index = entry.fetch(:index)
        next replacement_by_index.fetch(index) if replacement_by_index.key?(index)
        next if skipped_indices.include?(index)

        entry.fetch(:line)
      end
    end

    private

    attr_reader :entries

    def coalesced_group_actions
      mergeable_groups.filter_map do |_key, group_entries|
        coalescable_action(group_entries)
      end
    end

    def coalescable_action(group_entries)
      preferred_entries = group_entries.select { |entry| reconciled_unit_total?(entry.fetch(:line)) }

      if preferred_entries.any? && preferred_entries.size < group_entries.size
        return { merge_entries: preferred_entries, skip_entries: group_entries - preferred_entries }
      end

      if group_entries.size > 1 && unique_totals(group_entries).one?
        return { merge_entries: group_entries, skip_entries: [] }
      end

      nil
    end

    def merged_entry_for(group_entries)
      first_entry = group_entries.min_by { |entry| entry.fetch(:index) }
      return unless first_entry

      merged_line = group_entries.drop(1).each_with_object(first_entry.fetch(:line).dup) do |entry, line|
        merge_duplicate_item_line(line, entry.fetch(:line))
      end
      merged_line[:unit_price_cents] ||= inferred_unit_price_cents(merged_line) if group_entries.size > 1

      { line: merged_line, index: first_entry.fetch(:index) }
    end

    def mergeable_groups
      entries.each_with_object(Hash.new { |groups, key| groups[key] = [] }) do |entry, groups|
        key = duplicate_item_line_key(entry.fetch(:line))
        next unless key

        groups[key] << entry
      end
    end

    def merge_duplicate_item_line(target, source)
      target[:quantity] = decimal_line_value(target, :quantity) + decimal_line_value(source, :quantity)
      target[:total_cents] = integer_line_value(target, :total_cents) + integer_line_value(source, :total_cents)
    end

    def duplicate_item_line_key(line)
      return unless line[:kind].to_s == "item"
      return unless line[:unit_of_measure].to_s == "piece"
      return if line[:raw_text].blank?
      return if line[:label].blank?
      return if line[:quantity].nil?
      return if line[:total_cents].nil?

      %i[
        raw_text
        label
        label_truncated
        quantity
        unit_of_measure
        unit_price_cents
        vat_rate_bp
        tr_eligible
        kind
      ].map { |attribute| line[attribute] }
    end

    def reconciled_unit_total?(line)
      return false if line[:unit_price_cents].nil?

      quantity = decimal_line_value(line, :quantity)
      return false if quantity.zero?

      BigDecimal(integer_line_value(line, :unit_price_cents).to_s) * quantity == integer_line_value(line, :total_cents)
    end

    def inferred_unit_price_cents(line)
      quantity = decimal_line_value(line, :quantity)
      return if quantity.zero?

      unit_price = BigDecimal(integer_line_value(line, :total_cents).to_s) / quantity
      unit_price.to_i if unit_price == unit_price.to_i
    end

    def unique_totals(group_entries)
      group_entries.map { |entry| integer_line_value(entry.fetch(:line), :total_cents) }.uniq
    end

    def replacement_by_index
      @replacement_by_index ||= {}
    end

    def skipped_indices
      @skipped_indices ||= Set.new
    end

    def integer_line_value(line, attribute)
      line[attribute].to_i
    end

    def decimal_line_value(line, attribute)
      BigDecimal(line[attribute].to_s)
    end

    def line_attributes(line)
      attributes = line.is_a?(Hash) ? line.to_h : line.attributes
      attributes.each_with_object({}) do |(key, value), normalized|
        normalized[key.to_sym] = value
      end
    end
  end
end
