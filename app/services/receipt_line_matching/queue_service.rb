module ReceiptLineMatching
  # Builds the global backlog of unmatched receipt item lines grouped by label.
  class QueueService < ApplicationService
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

    def initialize(scope: ReceiptLine.all)
      @scope = scope
    end

    def call
      grouped_lines.map { |normalized_label, lines| build_group(normalized_label, lines) }
        .sort_by { |group| [ -group.line_count, group.normalized_label ] }
    end

    private

    attr_reader :scope

    def grouped_lines
      unmatched_item_lines.group_by { |line| normalized(line.label) }
    end

    def unmatched_item_lines
      scope
        .kind_item
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
