require "rails_helper"

RSpec.describe Parser::Leclerc::Paper::V2 do
  describe "registry" do
    it "registers the parser under the Leclerc paper v2 format" do
      expect(Parser::Registry.for("leclerc.paper.v2")).to eq(described_class)
    end
  end

  describe "#call" do
    it "parses quantity continuation lines with VAT rates from the breakdown table" do
      result = parse_fixture("parser/leclerc_paper_v2_quantity_vat.txt")

      expect(result.receipt).to include(quantity_receipt_attributes)
      expect(result.lines).to contain_exactly(quantity_line)
      expect(result.payments).to contain_exactly(card_payment(amount_cents: 1_070))
      expect(result.warnings).to be_empty
    end

    it "does not let eco-contribution detail rows replace pending quantity labels" do
      result = described_class.new(text: eco_contribution_quantity_text).call

      expect(result.receipt).to include(eco_contribution_quantity_receipt_attributes)
      expect(result.lines).to contain_exactly(eco_contribution_quantity_line)
      expect(result.payments).to contain_exactly(card_payment(amount_cents: 2_390))
      expect(result.warnings).to be_empty
    end

    it "parses section markers, direct item lines, split payments, and VAT codes" do
      result = parse_fixture("parser/leclerc_paper_v2_sections_vat.txt")

      expect(result.receipt).to include(sectioned_receipt_attributes)
      expect(result.lines).to contain_exactly(low_vat_line, medium_vat_line, high_vat_quantity_line)
      expect(result.promotions).to match_array(sectioned_promotions)
      expect(result.payments).to contain_exactly(immediate_discount_payment, voucher_payment, card_payment(amount_cents: 1_400))
      expect(result.warnings).to be_empty
    end

    it "parses Ticket Restaurant card payments with eligibility detail lines" do
      result = described_class.new(text: ticket_restaurant_payment_text).call

      expect(result.receipt).to include(ticket_restaurant_receipt_attributes)
      expect(result.payments).to contain_exactly(ticket_restaurant_payment, card_payment(amount_cents: 2_914))
      expect(result.warnings).to be_empty
    end
  end

  def parse_fixture(path)
    described_class.new(text: Rails.root.join("spec/fixtures/files", path).read).call
  end

  def quantity_receipt_attributes
    {
      parser_format: "leclerc.paper.v2",
      purchased_at: Time.zone.local(2025, 4, 4, 12, 56),
      register_number: "304-3004",
      ticket_number: "8P95 02Y00",
      total_cents: 1_070,
      declared_article_count: 2,
      parser_status: "parsed"
    }
  end

  def sectioned_receipt_attributes
    {
      parser_format: "leclerc.paper.v2",
      purchased_at: Time.zone.local(2025, 4, 12, 9, 15),
      register_number: "105-1005",
      ticket_number: "4A21 01B00",
      total_cents: 1_700,
      declared_article_count: 5,
      parser_status: "parsed"
    }
  end

  def eco_contribution_quantity_receipt_attributes
    {
      parser_format: "leclerc.paper.v2",
      purchased_at: Time.zone.local(2025, 9, 6, 15, 45),
      register_number: "305-3005",
      ticket_number: "8Q56 05900",
      total_cents: 2_390,
      declared_article_count: 2,
      parser_status: "parsed"
    }
  end

  def ticket_restaurant_receipt_attributes
    {
      parser_format: "leclerc.paper.v2",
      purchased_at: Time.zone.local(2025, 4, 5, 9, 20),
      register_number: "001-0128",
      ticket_number: "01A9 01C00",
      total_cents: 3_539,
      declared_article_count: 2,
      parser_status: "parsed"
    }
  end

  def ticket_restaurant_payment_text
    <<~TEXT
      ANONYMIZED STORE
      TEL:00.00.00.00.00
      Caisse 001-0128 05 avril 2025 09:20
      Ticket 05/04/25 0 01A9 01C00

      TTC   TVA
      ITEM FOOD                           6.25 1
      ITEM OTHER                         29.14 2
      ----------
      Total 2 articles                   35.39

      CB (T restau)                       6.25
      (montant éligible 6.25€
       plafonné à 25€)
      CB                                29.14

      Code               HT       TVA           TTC
      1 5%50           5.92      0.33          6.25
      2 20%00         24.28      4.86         29.14
    TEXT
  end

  def eco_contribution_quantity_text
    <<~TEXT
      ANONYMIZED STORE
      TEL:00.00.00.00.00
      Caisse 305-3005 06 septembre 2025 15:45
      Ticket 06/09/25 0 8Q56 05900

      TTC   TVA
      DOUDOU BALTA RENARD H23 BN6020 ..
      (A) Dont DEEE / DEA :              0.02
      (Z) Prix hors contributions :     11.93
      2 X 11.95€                        23.90 3
      ----------
      Total 2 articles                  23.90

      CB                                23.90

      Code               HT       TVA           TTC
      3 20%00         19.92      3.98         23.90
    TEXT
  end

  def quantity_line
    hash_including(
      position: 1,
      raw_text: "COLLANT H13 W1147 NOIR T2\n2 X 5.35€                   10.70 3",
      label: "COLLANT H13 W1147 NOIR T2",
      quantity: BigDecimal("2"),
      unit_price_cents: 535,
      total_cents: 1_070,
      vat_rate_bp: 2_000,
      section_label: nil
    )
  end

  def eco_contribution_quantity_line
    hash_including(
      position: 1,
      raw_text: "DOUDOU BALTA RENARD H23 BN6020 ..\n2 X 11.95€                        23.90 3",
      label: "DOUDOU BALTA RENARD H23 BN6020",
      label_truncated: true,
      quantity: BigDecimal("2"),
      unit_price_cents: 1_195,
      total_cents: 2_390,
      vat_rate_bp: 2_000,
      section_label: nil
    )
  end

  def low_vat_line
    hash_including(position: 1, label: "ITEM ALPHA BIO 250G", total_cents: 200, vat_rate_bp: 550, section_label: "EPICERIE")
  end

  def medium_vat_line
    hash_including(position: 2, label: "ITEM BRAVO", total_cents: 300, vat_rate_bp: 1_000, section_label: "EPICERIE")
  end

  def high_vat_quantity_line
    hash_including(
      position: 3,
      raw_text: "ITEM CHARLIE ..\n3 X 4.00€                    12.00 3",
      label: "ITEM CHARLIE",
      label_truncated: true,
      quantity: BigDecimal("3"),
      unit_price_cents: 400,
      total_cents: 1_200,
      vat_rate_bp: 2_000,
      section_label: "HYGIENE"
    )
  end

  def voucher_payment
    hash_including(raw_label: "Bon achat carte", category: "other", amount_cents: 100)
  end

  def immediate_discount_payment
    hash_including(raw_label: "Bon immediat", category: "other", amount_cents: 200)
  end

  def ticket_restaurant_payment
    hash_including(raw_label: "CB (T restau)", category: "tickets_restaurant", amount_cents: 625)
  end

  def bon_achat_promotion(amount_cents)
    {
      program: "leclerc_bon_achat_carte",
      unit: "euro_cents",
      delta: -amount_cents,
      label: "Bon achat carte",
      kind: "coupon",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def tickets_promotion(amount_cents)
    {
      program: "leclerc_tickets",
      unit: "euro_cents",
      delta: -amount_cents,
      label: "CUMUL DISPONIBLE",
      kind: "coupon",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def sectioned_promotions
    [
      bon_achat_promotion(100),
      tickets_promotion(100),
      item_bon_immediat_promotion,
      smeg_promotion
    ]
  end

  def smeg_promotion
    {
      program: "leclerc_vignettes_smeg",
      unit: "vignette_count",
      delta: 3,
      label: "SMEG",
      kind: "points_accrual",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def item_bon_immediat_promotion
    {
      program: "leclerc_bon_immediat",
      unit: "euro_cents",
      delta: -200,
      label: "ITEM ALPHA BIO 250G (X1)",
      kind: "immediate_discount",
      linked_line_position: 1,
      linking_method: "parser_inferred"
    }
  end

  def card_payment(amount_cents:)
    hash_including(raw_label: "CB", category: "bank_card", amount_cents: amount_cents)
  end
end
