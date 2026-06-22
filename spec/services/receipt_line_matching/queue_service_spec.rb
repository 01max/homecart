require "rails_helper"

RSpec.describe ReceiptLineMatching::QueueService do
  subject(:group) { described_class.call.find { |entry| entry.normalized_label == "lait demi ecreme" } }

  let(:store) { create(:store) }
  let!(:first_line) do
    create_lait_line(purchased_at: Time.zone.local(2026, 6, 1, 12), total_cents: 240, unit_price_cents: 120)
  end
  let!(:second_line) { create_lait_line(label: "LAIT demi écrémé", purchased_at: Time.zone.local(2026, 6, 3, 12)) }

  before do
    create(:receipt_line, receipt: create(:receipt, :reviewed), kind: "fee", label: "Service fee")
    create(:receipt_line, label: "Unreviewed item")
    create(:receipt_line, receipt: create(:receipt, :reviewed, purchased_at: nil), label: "Undated item")
    ignored_line = create(:receipt_line, receipt: create(:receipt, :reviewed), label: "Lait demi ecreme")
    create(:receipt_line_match, :ignored, receipt_line: ignored_line)
  end

  it "groups unmatched item lines by normalized label" do
    expect(group.receipt_lines).to contain_exactly(first_line, second_line)
    expect(group).to have_attributes(line_count: 2, stores: [ store ])
  end

  it "includes date and price context" do
    expect(group.first_purchased_at.to_date).to eq(Date.new(2026, 6, 1))
    expect(group.last_purchased_at.to_date).to eq(Date.new(2026, 6, 3))
    expect(group.price_context).to have_attributes(total_cents: [ 130, 240 ], unit_price_cents: [ 120, 130 ])
  end

  it "excludes reviewed receipts without purchase dates" do
    expect(described_class.call.flat_map(&:receipt_lines).map(&:label)).not_to include("Undated item")
  end

  it "filters groups by representative or normalized label" do
    create_queue_line(label: "Pain complet", purchased_at: Time.zone.local(2026, 6, 4, 12))

    expect(normalized_labels(described_class.call(label_filter: "écrémé"))).to eq([ "lait demi ecreme" ])
    expect(normalized_labels(described_class.call(label_filter: "pain"))).to eq([ "pain complet" ])
  end

  it "preserves unmatched item-line exclusions when filtering" do
    expect(described_class.call(label_filter: "service")).to be_empty
    expect(described_class.call(label_filter: "undated")).to be_empty
  end

  it "orders groups by label and line count" do
    create_orderable_groups

    expect(normalized_labels(described_class.call(sort: "label", direction: "asc")))
      .to eq([ "abricot", "banane", "lait demi ecreme" ])
    expect(normalized_labels(described_class.call(sort: "line_count", direction: "asc")))
      .to eq([ "abricot", "banane", "lait demi ecreme" ])
  end

  it "orders groups by purchase date range" do
    create_orderable_groups

    expect(normalized_labels(described_class.call(sort: "first_purchased_at", direction: "asc")))
      .to eq([ "lait demi ecreme", "abricot", "banane" ])
    expect(normalized_labels(described_class.call(sort: "last_purchased_at", direction: "desc")))
      .to eq([ "banane", "lait demi ecreme", "abricot" ])
  end

  it "falls back to the default ordering for unsupported sort fields" do
    create_queue_line(label: "Abricot", purchased_at: Time.zone.local(2026, 6, 2, 12))
    create_queue_line(label: "Banane", purchased_at: Time.zone.local(2026, 6, 5, 12))
    create_queue_line(label: "Banane", purchased_at: Time.zone.local(2026, 6, 6, 12))

    expect(normalized_labels(described_class.call(sort: "unsupported", direction: "desc")))
      .to eq(normalized_labels(described_class.call))
  end

  def create_lait_line(label: "Lait Demi Ecreme", purchased_at:, total_cents: 130, unit_price_cents: total_cents)
    create_queue_line(
      label: label,
      purchased_at: purchased_at,
      total_cents: total_cents,
      unit_price_cents: unit_price_cents
    )
  end

  def create_queue_line(label:, purchased_at:, total_cents: 130, unit_price_cents: total_cents)
    create(
      :receipt_line,
      receipt: create(:receipt, :reviewed, store: store, purchased_at: purchased_at),
      label: label,
      quantity: 1,
      total_cents: total_cents,
      unit_price_cents: unit_price_cents
    )
  end

  def create_orderable_groups
    create_queue_line(label: "Abricot", purchased_at: Time.zone.local(2026, 6, 2, 12))
    create_queue_line(label: "Banane", purchased_at: Time.zone.local(2026, 6, 5, 12))
    create_queue_line(label: "Banane", purchased_at: Time.zone.local(2026, 6, 6, 12))
  end

  def normalized_labels(groups)
    groups.map(&:normalized_label)
  end
end
