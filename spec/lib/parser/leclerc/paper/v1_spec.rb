require "rails_helper"

RSpec.describe Parser::Leclerc::Paper::V1 do
  describe "registry" do
    it "registers the parser under the Leclerc paper v1 format" do
      expect(Parser::Registry.for("leclerc.paper.v1")).to eq(described_class)
    end
  end

  describe "#call" do
    it "parses optional section markers and quantity continuation lines" do
      result = parse_fixture("parser/leclerc_paper_v1_with_sections.txt")

      expect(result.receipt).to include(sectioned_receipt_attributes)
      expect(result.lines).to contain_exactly(quantity_line, starred_line, regular_line, section_line)
      expect(result.payments).to contain_exactly(card_payment(amount_cents: 1_773))
      expect(result.warnings).to be_empty
    end

    it "parses receipts without section markers and split payments" do
      result = parse_fixture("parser/leclerc_paper_v1_without_sections.txt")

      expect(result.receipt).to include(unsectioned_receipt_attributes)
      expect(result.lines).to contain_exactly(unsectioned_line("ITEM SINGLE", 284), unsectioned_line("ITEM SECOND", 305), unsectioned_line("ITEM THIRD", 400))
      expect(result.promotions).to contain_exactly(bon_achat_promotion(193), tickets_promotion(193), royal_vkb_promotion)
      expect(result.payments).to contain_exactly(voucher_payment, card_payment(amount_cents: 796))
      expect(result.warnings).to be_empty
    end

    it "does not infer a tickets promotion from displayed CUMUL DISPONIBLE balances" do
      text = Rails.root.join("spec/fixtures/files/parser/leclerc_paper_v1_without_sections.txt").read
                 .sub("CUMUL DISPONIBLE", "CUMUL DISPONIBLE AU 03/09/24 : 0.00 €")

      result = described_class.new(text: text).call

      expect(result.promotions).to contain_exactly(bon_achat_promotion(193), royal_vkb_promotion)
      expect(result.payments).to contain_exactly(voucher_payment, card_payment(amount_cents: 796))
      expect(result.warnings).to be_empty
    end

    it "parses receipt-level discounts and immediate discount payments" do
      result = parse_fixture("parser/leclerc_paper_v1_receipt_level_discounts.txt")

      expect(result.receipt).to include(discounted_receipt_attributes)
      expect(result.lines).to match_array(receipt_level_discount_lines)
      expect(result.promotions).to match_array(discounted_receipt_promotions)
      expect(result.payments).to match_array(discounted_receipt_payments)
      expect(result.warnings).to be_empty
    end

    it "parses Ticket Restaurant card payments with eligibility detail lines" do
      result = described_class.new(text: ticket_restaurant_payment_text).call

      expect(result.receipt).to include(ticket_restaurant_receipt_attributes)
      expect(result.payments).to contain_exactly(ticket_restaurant_payment, card_payment(amount_cents: 2_914))
      expect(result.warnings).to be_empty
    end

    it "parses CYCLEEN bottle recycling credits as payments" do
      result = described_class.new(text: cycleen_recycling_credit_text).call

      expect(result.receipt).to include(cycleen_recycling_credit_receipt_attributes)
      expect(result.lines).to contain_exactly(cycleen_item_line)
      expect(result.payments).to contain_exactly(cycleen_payment, card_payment(amount_cents: 984))
      expect(result.warnings).to be_empty
    end

    it "uses a plain vignette heading as the campaign for unlabeled vignette events" do
      text = Rails.root.join("spec/fixtures/files/parser/leclerc_paper_v1_receipt_level_discounts.txt").read
                 .sub("---- VOS VIGNETTES MONBENTO ----", "Vos vignettes SMEG")

      result = described_class.new(text: text).call

      expect(result.promotions).to include(smeg_accrual_promotion, smeg_consumption_promotion)
      expect(result.warnings).to be_empty
    end

    it "uses a following operation banner as the campaign for unlabeled vignette events" do
      result = described_class.new(text: pyrex_vignette_operation_text).call

      expect(result.promotions).to contain_exactly(pyrex_accrual_promotion)
      expect(result.warnings).to be_empty
    end

    it "parses Amazones/Jeannerie loyalty point accrual events" do
      result = described_class.new(text: amazones_jeannerie_points_text).call

      expect(result.lines).to include(discount_line("RAYON CAPSULE", -1_498))
      expect(result.promotions).to contain_exactly(amazones_jeannerie_points_accrual_promotion)
      expect(result.warnings).to be_empty
    end

    it "keeps generic point balance events out of promotions" do
      text = amazones_jeannerie_points_text.sub("Cumul points fidélité Amazones/Jeannerie", "Cumul points fidélité Other Program")

      result = described_class.new(text: text).call

      expect(result.promotions).to be_empty
      expect(result.warnings).to be_empty
    end
  end

  def parse_fixture(path)
    described_class.new(text: Rails.root.join("spec/fixtures/files", path).read).call
  end

  def sectioned_receipt_attributes
    {
      parser_format: "leclerc.paper.v1",
      purchased_at: Time.zone.local(2024, 10, 5, 16, 45),
      register_number: "001-0102",
      ticket_number: "01A9 0DT00",
      total_cents: 1_773,
      declared_article_count: 6,
      parser_status: "parsed"
    }
  end

  def unsectioned_receipt_attributes
    {
      parser_format: "leclerc.paper.v1",
      purchased_at: Time.zone.local(2024, 9, 2, 12, 50),
      register_number: "302-3002",
      ticket_number: "8M8G 02U00",
      total_cents: 989,
      declared_article_count: 3,
      parser_status: "parsed"
    }
  end

  def discounted_receipt_attributes
    {
      parser_format: "leclerc.paper.v1",
      purchased_at: Time.zone.local(2025, 11, 1, 11, 0),
      register_number: "010-0105",
      ticket_number: "0AUU 00X00",
      total_cents: 1_428,
      declared_article_count: 4,
      parser_status: "parsed"
    }
  end

  def ticket_restaurant_receipt_attributes
    {
      parser_format: "leclerc.paper.v1",
      purchased_at: Time.zone.local(2025, 4, 5, 9, 20),
      register_number: "001-0128",
      ticket_number: "01A9 01C00",
      total_cents: 3_539,
      declared_article_count: 2,
      parser_status: "parsed"
    }
  end

  def cycleen_recycling_credit_receipt_attributes
    {
      parser_format: "leclerc.paper.v1",
      purchased_at: Time.zone.local(2025, 7, 5, 9, 34),
      register_number: "022-0115",
      ticket_number: "0MWK 01S00",
      total_cents: 1_000,
      declared_article_count: 1,
      parser_status: "parsed"
    }
  end

  def amazones_jeannerie_points_text
    <<~TEXT
      ANONYMIZED STORE
      TEL:00.00.00.00.00
      Caisse 053-0310 04 septembre 2024 10:32
      04/09/24 0 1I4A 00P00

      H22 PULL AUXANNE GRIS S/M            29.95
      H24 F PANT 10255128 VMZAMIRA         39.99

      Remises RAYON                       -14.98
                                      ----------
      Total 2 articles                     54.96

      CB                                   54.96

      ----------------------------------------
                      REMISES

      RAYON CAPSULE                      14.98
        H22 PULL AUXANNE GRIS S/M
        H24 F PANT 10255128 VMZAMIRA
      ----------------------------------------

      Cumul points fidélité Amazones/Jeannerie

      Solde précédent       :          0 point
      Vous venez d'obtenir :          54 point
      Solde actuel          :         54 point
      ----------------------------------------
    TEXT
  end

  def ticket_restaurant_payment_text
    <<~TEXT
      ANONYMIZED STORE
      TEL:00.00.00.00.00
      Caisse 001-0128 05 avril 2025 09:20
      05/04/25 0 01A9 01C00

      ITEM FOOD                              6.25
      ITEM OTHER                            29.14
                                      ----------
      Total 2 articles                      35.39

      CB (T restau)                          6.25
      (montant éligible 6.25€
       plafonné à 25€)
      CB                                    29.14
    TEXT
  end

  def cycleen_recycling_credit_text
    <<~TEXT
      ANONYMIZED STORE
      TEL:00.00.00.00.00
      Caisse 022-0115 05 juillet 2025 09:34
      05/07/25 0 0MWK 01S00

      ITEM ALPHA                            10.00
                                      ----------
      Total 1 article                       10.00

      CYCLEEN                                0.16
      CB                                     9.84
    TEXT
  end

  def pyrex_vignette_operation_text
    <<~TEXT
      ANONYMIZED STORE
      TEL:00.00.00.00.00
      Caisse 302-3002 06 mars 2024 14:09
      06/03/24 0 8M8G 03600

      ITEM ALPHA                            10.75
                                      ----------
      Total 1 article                       10.75

      CB                                    10.75

      Solde précédent       :      54 Vignette(s)
      Vous venez d'obtenir :       1 Vignette(s)
      Solde actuel          :      55 Vignette(s)

      Détail des avantages obtenus :
      Sur total ticket             1 Vignette(s)
      ----------------------------------------
              OPERATION VIGNETTES PYREX
      ----------------------------------------
    TEXT
  end

  def quantity_line
    hash_including(
      position: 1,
      raw_text: "ITEM ALPHA BIO 250G\n3 X 3.54€                    10.62",
      label: "ITEM ALPHA BIO 250G",
      quantity: BigDecimal("3"),
      unit_price_cents: 354,
      total_cents: 1_062,
      section_label: "EPICERIE"
    )
  end

  def starred_line
    hash_including(position: 2, label: "ITEM BRAVO", total_cents: 179, tr_eligible: false, section_label: "EPICERIE")
  end

  def regular_line
    hash_including(position: 3, label: "ITEM CHARLIE", total_cents: 321, section_label: "EPICERIE")
  end

  def section_line
    hash_including(position: 4, label: "ITEM DELTA", total_cents: 211, section_label: "CHARCUTERIE LS")
  end

  def unsectioned_line(label, total_cents)
    hash_including(label: label, quantity: BigDecimal("1"), total_cents: total_cents, section_label: nil)
  end

  def discount_line(label, total_cents)
    hash_including(label: label, quantity: BigDecimal("1"), total_cents: total_cents, section_label: nil, kind: "discount")
  end

  def receipt_level_discount_lines
    [
      unsectioned_line("ITEM ALPHA", 1_000),
      unsectioned_line("COOKIES TRIPLE CHOCO,136G", 264),
      unsectioned_line("COUPON SET 3 COUVERTS,1KG", 1),
      unsectioned_line("SET 3 COUVERTS,1", 1_700),
      discount_line("COUPON SET 3 COUVERTS,1KG", -1),
      discount_line("Lot KIWI VERT LOT DE 5", -36),
      discount_line("Lot Set de couverts", -1_500)
    ]
  end

  def voucher_payment
    hash_including(raw_label: "Bon achat carte", category: "other", amount_cents: 193)
  end

  def immediate_discount_payment
    hash_including(raw_label: "Bon immediat", category: "other", amount_cents: 239)
  end

  def ticket_restaurant_payment
    hash_including(raw_label: "CB (T restau)", category: "tickets_restaurant", amount_cents: 625)
  end

  def cycleen_payment
    hash_including(raw_label: "CYCLEEN", category: "other", amount_cents: 16)
  end

  def cycleen_item_line
    hash_including(position: 1, label: "ITEM ALPHA", quantity: BigDecimal("1"), total_cents: 1_000, kind: "item")
  end

  def discounted_receipt_payments
    [ immediate_discount_payment, card_payment(amount_cents: 1_189) ]
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

  def royal_vkb_promotion
    {
      program: "leclerc_vignettes_royal_vkb",
      unit: "vignette_count",
      delta: 2,
      label: "Royal VKB",
      kind: "points_accrual",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def monbento_accrual_promotion
    {
      program: "leclerc_vignettes_monbento",
      unit: "vignette_count",
      delta: 14,
      label: "MONBENTO",
      kind: "points_accrual",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def monbento_consumption_promotion
    {
      program: "leclerc_vignettes_monbento",
      unit: "vignette_count",
      delta: -35,
      label: "MONBENTO",
      kind: "points_consumption",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def smeg_accrual_promotion
    {
      program: "leclerc_vignettes_smeg",
      unit: "vignette_count",
      delta: 14,
      label: "SMEG",
      kind: "points_accrual",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def smeg_consumption_promotion
    {
      program: "leclerc_vignettes_smeg",
      unit: "vignette_count",
      delta: -35,
      label: "SMEG",
      kind: "points_consumption",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def pyrex_accrual_promotion
    {
      program: "leclerc_vignettes_pyrex",
      unit: "vignette_count",
      delta: 1,
      label: "PYREX",
      kind: "points_accrual",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def amazones_jeannerie_points_accrual_promotion
    {
      program: "leclerc_points_amazones_jeannerie",
      unit: "point_count",
      delta: 54,
      label: "Amazones/Jeannerie",
      kind: "points_accrual",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def cookies_bon_immediat_promotion
    {
      program: "leclerc_bon_immediat",
      unit: "euro_cents",
      delta: -90,
      label: "COOKIES TRIPLE CHOCO,136G",
      kind: "immediate_discount",
      linked_line_position: 2,
      linking_method: "parser_inferred"
    }
  end

  def sauce_lot_bon_immediat_promotion
    {
      program: "leclerc_bon_immediat",
      unit: "euro_cents",
      delta: -149,
      label: "Lot LOT BRII 2M68PCT SAUCE MUTT",
      kind: "immediate_discount",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def discounted_receipt_promotions
    [
      cookies_bon_immediat_promotion,
      sauce_lot_bon_immediat_promotion,
      monbento_accrual_promotion,
      monbento_consumption_promotion
    ]
  end

  def card_payment(amount_cents:)
    hash_including(raw_label: "CB", category: "bank_card", amount_cents: amount_cents)
  end
end
