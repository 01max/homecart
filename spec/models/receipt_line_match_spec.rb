require "rails_helper"

RSpec.describe ReceiptLineMatch do
  it "belongs to receipt lines and optional product variants" do
    line = create(:receipt_line)
    variant = create(:product_variant)
    match = create(:receipt_line_match, receipt_line: line, product_variant: variant)

    expect(match.receipt_line).to eq(line)
    expect(match.product_variant).to eq(variant)
  end

  it "declares status and source enums" do
    match = build(:receipt_line_match, :suggested)

    expect(described_class.statuses.keys).to contain_exactly("suggested", "confirmed", "rejected", "ignored")
    expect(described_class.sources.keys).to contain_exactly("user", "heuristic")
    expect(match.suggested?).to be(true)
    expect(match.source_heuristic?).to be(true)
  end

  it "requires product variants for suggested, confirmed, and rejected matches" do
    suggested = build(:receipt_line_match, :suggested, product_variant: nil)
    confirmed = build(:receipt_line_match, product_variant: nil)
    rejected = build(:receipt_line_match, :rejected, product_variant: nil)

    expect(suggested).not_to be_valid
    expect(confirmed).not_to be_valid
    expect(rejected).not_to be_valid
  end

  it "forbids product variants for ignored matches" do
    ignored = build(:receipt_line_match, :ignored)
    ignored_with_variant = build(:receipt_line_match, :ignored, product_variant: create(:product_variant))

    expect(ignored).to be_valid
    expect(ignored_with_variant).not_to be_valid
  end

  it "allows many non-terminal decisions for the same receipt line" do
    line = create(:receipt_line)
    first = create(:receipt_line_match, :suggested, receipt_line: line)
    second = build(:receipt_line_match, :rejected, receipt_line: line)

    expect(second).to be_valid
    expect(described_class.where(receipt_line: line)).to contain_exactly(first)
  end

  it "allows only one terminal decision for the same receipt line" do
    line = create(:receipt_line)
    create(:receipt_line_match, receipt_line: line)

    ignored = build(:receipt_line_match, :ignored, receipt_line: line)

    expect(ignored).not_to be_valid
  end

  it "scopes terminal decisions" do
    confirmed = create(:receipt_line_match)
    ignored = create(:receipt_line_match, :ignored)
    create(:receipt_line_match, :suggested)
    create(:receipt_line_match, :rejected)

    expect(described_class.terminal_decisions).to contain_exactly(confirmed, ignored)
  end

  it "does not mutate receipt-line evidence" do
    line = create(:receipt_line)
    evidence_attributes = %w[ raw_text label quantity unit_of_measure unit_price_cents total_cents kind ]
    original_evidence = line.reload.attributes.slice(*evidence_attributes)

    create(:receipt_line_match, receipt_line: line, label_snapshot: "Curated label")

    expect(line.reload.attributes.slice(*evidence_attributes)).to eq(original_evidence)
  end
end
