require "rails_helper"

RSpec.describe Parser::MagasinsU::Paper::V1 do
  describe "registry" do
    it "registers the parser under the U paper v1 format" do
      expect(Parser::Registry.for("u.paper.v1")).to eq(described_class)
    end
  end

  describe "#call" do
    it "parses section markers, piece quantity continuations, and weighted quantity continuations" do
      result = parse_fixture("parser/u_paper_v1_weighted_quantity.txt")

      expect(result.receipt).to include(weighted_receipt_attributes)
      expect(result.lines).to contain_exactly(piece_quantity_line, weighted_quantity_line, direct_line)
      expect(result.promotions).to contain_exactly(jbl_vignette_promotion)
      expect(result.payments).to contain_exactly(card_payment(amount_cents: 1_027))
      expect(result.warnings).to be_empty
    end

    it "parses direct item lines and preserves truncated labels" do
      result = parse_fixture("parser/u_paper_v1_direct_items.txt")

      expect(result.receipt).to include(direct_receipt_attributes)
      expect(result.lines).to contain_exactly(soup_line, truncated_line, produce_line)
      expect(result.promotions).to contain_exactly(carte_u_promotion(35))
      expect(result.payments).to contain_exactly(cash_payment(amount_cents: 717))
      expect(result.warnings).to be_empty
    end
  end

  def parse_fixture(path)
    described_class.new(text: Rails.root.join("spec/fixtures/files", path).read).call
  end

  def weighted_receipt_attributes
    {
      parser_format: "u.paper.v1",
      purchased_at: Time.zone.local(2025, 6, 15, 8, 58),
      register_number: "1",
      ticket_number: "450250",
      cashier_code: "106    LV",
      total_cents: 1_027,
      declared_article_count: 4,
      parser_status: "parsed"
    }
  end

  def direct_receipt_attributes
    {
      parser_format: "u.paper.v1",
      purchased_at: Time.zone.local(2025, 2, 19, 11, 51),
      register_number: "2",
      ticket_number: "405251",
      cashier_code: "101    MT",
      total_cents: 717,
      declared_article_count: 3,
      parser_status: "parsed"
    }
  end

  def piece_quantity_line
    hash_including(
      position: 1,
      raw_text: "TORTELLINI RICOTT.EPINA.U 300G\n2 x     2,41 €                                 4,82 €   11",
      label: "TORTELLINI RICOTT.EPINA.U 300G",
      quantity: BigDecimal("2"),
      unit_of_measure: "piece",
      unit_price_cents: 241,
      total_cents: 482,
      vat_rate_bp: 550,
      section_label: "CHARC.TRAIT.SAUC.SECS L"
    )
  end

  def weighted_quantity_line
    hash_including(
      position: 2,
      raw_text: "COURGETTE 11\n2,056 kg x      1,29 €/kg                2,65 €",
      label: "COURGETTE",
      quantity: BigDecimal("2.056"),
      unit_of_measure: "kg",
      unit_price_cents: 129,
      total_cents: 265,
      vat_rate_bp: 550,
      section_label: "FRUITS ET LEGUMES"
    )
  end

  def direct_line
    hash_including(position: 3, label: "BRIOC.TRANC.NATURE HARRYS 485G", total_cents: 280, vat_rate_bp: 550, section_label: "PAT INDUSTRIELLE")
  end

  def soup_line
    hash_including(position: 1, label: "DELICE POTIRON/CHATA.LIEBIG 1L", total_cents: 377, section_label: "EPICERIE")
  end

  def truncated_line
    hash_including(position: 2, label: "PRINCE MULTI.CEREALE.LU PQ293G", label_truncated: true, total_cents: 190, section_label: "EPICERIE")
  end

  def produce_line
    hash_including(position: 3, label: "CONCOMBRE", total_cents: 150, vat_rate_bp: 550, section_label: "FRUITS ET LEGUMES")
  end

  def carte_u_promotion(delta)
    {
      program: "u_carte_u",
      unit: "euro_cents",
      delta: delta,
      label: "Carte U solde",
      kind: "loyalty_cash_credit",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def jbl_vignette_promotion
    {
      program: "u_vignettes_jbl",
      unit: "vignette_count",
      delta: 8,
      label: "JBL",
      kind: "points_accrual",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def card_payment(amount_cents:)
    hash_including(raw_label: "CB SANS CONTACT VX", category: "bank_card", amount_cents: amount_cents)
  end

  def cash_payment(amount_cents:)
    hash_including(raw_label: "ESPECES", category: "cash", amount_cents: amount_cents)
  end
end
