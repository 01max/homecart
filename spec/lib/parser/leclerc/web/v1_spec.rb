require "rails_helper"

RSpec.describe Parser::Leclerc::Web::V1 do
  describe "registry" do
    it "registers the parser under the Leclerc web v1 format" do
      expect(Parser::Registry.for("leclerc.web.v1")).to eq(described_class)
    end
  end

  describe "#call" do
    it "parses Drive receipts with a delivery fee line" do
      result = parse_fixture("parser/leclerc_web_v1_drive.txt")

      expect(result.receipt).to include(drive_receipt_attributes)
      expect(result.lines).to contain_exactly(drive_item_line, drive_quantity_line, drive_fee_line)
      expect(result.payments).to contain_exactly(drive_payment)
      expect(result.warnings).to be_empty
    end

    it "parses Click & Collect receipts without a delivery fee" do
      result = parse_fixture("parser/leclerc_web_v1_click_collect.txt")

      expect(result.receipt).to include(click_collect_receipt_attributes)
      expect(result.lines).to contain_exactly(click_collect_item_line)
      expect(result.payments).to contain_exactly(click_collect_payment)
      expect(result.warnings).to be_empty
    end
  end

  def parse_fixture(path)
    described_class.new(text: Rails.root.join("spec/fixtures/files", path).read).call
  end

  def drive_receipt_attributes
    {
      parser_format: "leclerc.web.v1",
      purchased_at: Time.zone.local(2025, 4, 20),
      total_cents: 1_000,
      declared_article_count: 3,
      parser_status: "parsed"
    }
  end

  def click_collect_receipt_attributes
    {
      parser_format: "leclerc.web.v1",
      purchased_at: Time.zone.local(2026, 1, 8),
      total_cents: 9_490,
      declared_article_count: 1,
      parser_status: "parsed"
    }
  end

  def drive_item_line
    hash_including(position: 1, label: "ITEM ALPHA BIO", quantity: BigDecimal("1"), total_cents: 200, kind: "item")
  end

  def drive_quantity_line
    hash_including(position: 2, label: "ITEM BRAVO", quantity: BigDecimal("2"), total_cents: 500, kind: "item")
  end

  def drive_fee_line
    hash_including(
      position: 3,
      label: "FRAIS DE LIVRAISON A 5.5%",
      quantity: BigDecimal("1"),
      total_cents: 300,
      vat_rate_bp: 550,
      kind: "fee"
    )
  end

  def click_collect_item_line
    hash_including(position: 1, label: "ANONYMIZED ITEM", quantity: BigDecimal("1"), total_cents: 9_490, kind: "item")
  end

  def drive_payment
    hash_including(raw_label: "CB Web Drive", category: "web", amount_cents: 1_000)
  end

  def click_collect_payment
    hash_including(raw_label: "CB Web C&C SUE", category: "web", amount_cents: 9_490)
  end
end
