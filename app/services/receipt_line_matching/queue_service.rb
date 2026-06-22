module ReceiptLineMatching
  # Builds the global backlog of unmatched receipt item lines grouped by label.
  class QueueService < ApplicationService
    DEFAULT_SORT = "line_count"
    DIRECTIONS = %w[asc desc].freeze
    SORT_FIELDS = %w[line_count label first_purchased_at last_purchased_at].freeze
    DEFAULT_DIRECTIONS = {
      "line_count" => "desc",
      "label" => "asc",
      "first_purchased_at" => "asc",
      "last_purchased_at" => "desc"
    }.freeze

    Group = Data.define(
      :normalized_label,
      :representative_label,
      :line_count,
      :receipt_lines,
      :stores,
      :first_purchased_at,
      :last_purchased_at,
      :price_context
    )
    PriceContext = Data.define(:total_cents, :unit_price_cents, :quantities, :units)

    def initialize(scope: ReceiptLine.all, label_filter: nil, sort: nil, direction: nil)
      @scope = scope
      @label_filter = label_filter.to_s.strip
      @sort = sort.to_s
      @direction = direction.to_s
    end

    def call
      groups = grouped_lines.map { |normalized_label, lines| build_group(normalized_label, lines) }

      ordered_groups(filtered_groups(groups))
    end

    private

    attr_reader :scope, :label_filter, :sort, :direction

    def filtered_groups(groups)
      return groups if label_filter.blank?

      groups.select { |group| label_filter_match?(group) }
    end

    def label_filter_match?(group)
      group.representative_label.downcase.include?(label_filter.downcase) ||
        group.normalized_label.include?(normalized_label_filter)
    end

    def normalized_label_filter
      @normalized_label_filter ||= normalized(label_filter)
    end

    def ordered_groups(groups)
      groups.sort do |left, right|
        comparison = sort_value(left) <=> sort_value(right)
        comparison *= -1 if sort_direction == "desc"

        comparison.zero? ? left.normalized_label <=> right.normalized_label : comparison
      end
    end

    def sort_value(group)
      case sort_field
      when "line_count"
        group.line_count
      when "label"
        group.representative_label.downcase
      when "first_purchased_at"
        group.first_purchased_at
      when "last_purchased_at"
        group.last_purchased_at
      end
    end

    def sort_field
      @sort_field ||= SORT_FIELDS.include?(sort) ? sort : DEFAULT_SORT
    end

    def sort_direction
      @sort_direction ||= DIRECTIONS.include?(direction) ? direction : DEFAULT_DIRECTIONS.fetch(sort_field)
    end

    def grouped_lines
      unmatched_item_lines.group_by { |line| normalized(line.label) }
    end

    def unmatched_item_lines
      scope
        .kind_item
        .joins(:receipt)
        .where(receipts: { parser_status: "reviewed" })
        .where.not(receipts: { purchased_at: nil })
        .where.not(id: ReceiptLineMatch.terminal_decisions.select(:receipt_line_id))
        .includes(receipt: { store: :retail_brand })
        .order(:label, :id)
    end

    def build_group(normalized_label, lines)
      Group.new(
        normalized_label: normalized_label,
        representative_label: representative_label(lines),
        line_count: lines.size,
        receipt_lines: lines,
        stores: stores(lines),
        first_purchased_at: purchased_dates(lines).min,
        last_purchased_at: purchased_dates(lines).max,
        price_context: price_context(lines)
      )
    end

    def representative_label(lines)
      lines.group_by(&:label).max_by { |label, grouped_lines| [ grouped_lines.size, -label.length, label ] }.first
    end

    def stores(lines)
      lines.map { |line| line.receipt.store }
        .uniq
        .sort_by { |store| store_sort_key(store) }
    end

    def store_sort_key(store)
      [ store.retail_brand.name, store.location_name, store.channel ]
    end

    def purchased_dates(lines)
      lines.filter_map { |line| line.receipt.purchased_at }
    end

    def price_context(lines)
      PriceContext.new(
        total_cents: sorted_values(lines.map(&:total_cents)),
        unit_price_cents: sorted_values(lines.map(&:unit_price_cents)),
        quantities: sorted_values(lines.map(&:quantity)),
        units: sorted_values(lines.map(&:unit_of_measure))
      )
    end

    def sorted_values(values)
      values.compact.uniq.sort
    end

    def normalized(label)
      ProductCatalog::NormalizeTextService.call(label)
    end
  end
end
