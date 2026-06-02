require "rails_helper"

RSpec.describe Parser::MagasinsU::Paper::V2 do
  describe "registry" do
    it "registers the parser under the U paper v2 format" do
      expect(Parser::Registry.for("u.paper.v2")).to eq(described_class)
    end
  end

  describe "#call" do
    it "parses OmniPOS quantity lines, TR markers, section words, and split payments" do
      result = parse_fixture("parser/u_paper_v2_multi_payment.txt")

      expect(result.receipt).to include(multi_payment_receipt_attributes)
      expect(result.lines).to contain_exactly(cucumber_line, toiletry_line, rice_line)
      expect(result.payments).to contain_exactly(tickets_restaurant_payment, card_payment(amount_cents: 454))
      expect(result.warnings).to be_empty
    end

    it "parses single-payment OmniPOS receipts with VAT mapping" do
      result = parse_fixture("parser/u_paper_v2_single_payment.txt")

      expect(result.receipt).to include(single_payment_receipt_attributes)
      expect(result.lines).to contain_exactly(water_line, toy_line)
      expect(result.payments).to contain_exactly(card_payment(amount_cents: 810))
      expect(result.warnings).to be_empty
    end
  end

  def parse_fixture(path)
    described_class.new(text: Rails.root.join("spec/fixtures/files", path).read).call
  end

  def multi_payment_receipt_attributes
    {
      parser_format: "u.paper.v2",
      purchased_at: Time.zone.local(2026, 5, 15, 10, 29, 10),
      register_number: "002",
      ticket_number: "14515",
      cashier_code: "102",
      total_cents: 952,
      declared_article_count: 3,
      parser_status: "parsed"
    }
  end

  def single_payment_receipt_attributes
    {
      parser_format: "u.paper.v2",
      purchased_at: Time.zone.local(2026, 3, 22, 10, 31, 55),
      register_number: "003",
      ticket_number: "67521",
      cashier_code: "104",
      total_cents: 810,
      declared_article_count: 2,
      parser_status: "parsed"
    }
  end

  def cucumber_line
    hash_including(
      position: 1,
      raw_text: "CONCOMBRE                              (T)         0,79 €      11\n1 x        0,79 EUR",
      label: "CONCOMBRE",
      quantity: BigDecimal("1"),
      unit_of_measure: "piece",
      unit_price_cents: 79,
      total_cents: 79,
      vat_rate_bp: 550,
      tr_eligible: true,
      section_label: "LEGUMES"
    )
  end

  def toiletry_line
    hash_including(position: 2, label: "SH.SEC PARF.ORIG.BATISTE 200ML", total_cents: 454, vat_rate_bp: 2_000, tr_eligible: false, section_label: "PARFUMERIE")
  end

  def rice_line
    hash_including(position: 3, label: "RIZ BASMATI ORIGINE PENJAB U1K", total_cents: 419, vat_rate_bp: 550, tr_eligible: true, section_label: "RIZ")
  end

  def water_line
    hash_including(position: 1, label: "EAU MINERALE VITTEL PET 1,5L", total_cents: 52, vat_rate_bp: 550, section_label: "EAUX")
  end

  def toy_line
    hash_including(position: 2, label: "SEAU GARNI + ARR LICORNE", total_cents: 758, vat_rate_bp: 2_000, section_label: "JOUETS")
  end

  def tickets_restaurant_payment
    hash_including(raw_label: "CB TRD 4COINS SANS CONTACT", category: "tickets_restaurant", amount_cents: 498)
  end

  def card_payment(amount_cents:)
    hash_including(raw_label: "CB SANS CONTACT", category: "bank_card", amount_cents: amount_cents)
  end
end
