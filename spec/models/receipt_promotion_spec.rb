require "rails_helper"

RSpec.describe ReceiptPromotion do
  it "belongs to a receipt" do
    receipt = create(:receipt)
    promotion = create(:receipt_promotion, receipt: receipt)

    expect(receipt.receipt_promotions).to contain_exactly(promotion)
  end

  it "can link to a receipt line" do
    line = create(:receipt_line)
    promotion = create(:receipt_promotion, receipt: line.receipt, linked_line: line, linking_method: "parser_inferred")

    expect(line.receipt_promotions).to contain_exactly(promotion)
  end

  it "declares promotion enums" do
    expect(described_class.units.keys).to contain_exactly("euro_cents", "vignette_count", "point_count")
    expect(described_class.linking_methods.keys).to contain_exactly("parser_inferred", "user_confirmed", "unallocated")
  end

  it "requires unallocated when no linked line is recorded" do
    promotion = create(:receipt_promotion).tap { |record| record.linking_method = "parser_inferred" }

    expect(promotion).not_to be_valid
  end

  it "rejects unallocated when a linked line is present" do
    line = create(:receipt_line)
    promotion = create(:receipt_promotion, receipt: line.receipt, linked_line: line, linking_method: "parser_inferred")
    promotion.linking_method = "unallocated"

    expect(promotion).not_to be_valid
  end
end
