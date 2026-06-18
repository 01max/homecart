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

  def create_lait_line(label: "Lait Demi Ecreme", purchased_at:, total_cents: 130, unit_price_cents: total_cents)
    create(
      :receipt_line,
      receipt: create(:receipt, :reviewed, store: store, purchased_at: purchased_at),
      label: label,
      quantity: 1,
      total_cents: total_cents,
      unit_price_cents: unit_price_cents
    )
  end
end
