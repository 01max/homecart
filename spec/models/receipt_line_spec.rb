require "rails_helper"

RSpec.describe ReceiptLine do
  it "belongs to a receipt" do
    receipt = create(:receipt)
    line = create(:receipt_line, receipt: receipt)

    expect(receipt.receipt_lines).to contain_exactly(line)
  end

  it "declares unit and kind enums" do
    line = create(:receipt_line)

    expect(line.piece?).to be(true)
    expect(line.kind_item?).to be(true)
  end

  it "requires unique positions within a receipt" do
    line = create(:receipt_line)
    duplicate = create(:receipt_line, receipt: line.receipt, position: 2)
    duplicate.position = line.position

    expect(duplicate).not_to be_valid
  end

  it "validates booleans" do
    line = create(:receipt_line).tap { |record| record.tr_eligible = nil }

    expect(line).not_to be_valid
  end

  it "validates amounts" do
    line = create(:receipt_line).tap { |record| record.total_cents = nil }

    expect(line).not_to be_valid
  end
end
