require "rails_helper"

RSpec.describe Parser::Auchan::Paper::V1 do
  describe "registry" do
    it "registers the parser under the Auchan paper v1 format" do
      expect(Parser::Registry.for("auchan.paper.v1")).to eq(described_class)
    end
  end

  describe "#call" do
    it "parses cashier-staffed receipts without Selfscan markers" do
      result = parse_fixture("parser/auchan_paper_v1_cashier.txt")

      expect(result.receipt).to include(cashier_receipt_attributes)
      expect(result.lines).to contain_exactly(cashier_tr_line, cashier_quantity_line)
      expect(result.promotions).to contain_exactly(cashier_waaoh_promotion)
      expect(result.payments).to contain_exactly(cashier_payment)
      expect(result.warnings).to be_empty
    end

    it "parses Selfscan receipts, discount adjustments, and scan warnings" do
      result = parse_fixture("parser/auchan_paper_v1_selfscan.txt")

      expect(result.receipt).to include(selfscan_receipt_attributes)
      expect(result.lines).to include(selfscan_item_line, selfscan_discounted_item_line, selfscan_discount_line)
      expect(result.payments).to include(selfscan_cash_payment, selfscan_card_payment)
      expect(result.warnings).to contain_exactly(selfscan_warning("Lecture partielle incorrecte"), selfscan_warning("Nouveau scan incorrect"))
    end

    it "keeps parser annotations out of item lines" do
      result = parse_fixture("parser/auchan_paper_v1_selfscan.txt")

      expect(result.lines.pluck(:raw_text)).not_to include("(Erreur de balisage)", "> Garantie légale 24 mois")
    end

    it "keeps selfscan correction rows out of WAAOH promotions" do
      result = described_class.new(text: cashier_text_with_scan_corrections).call

      expect(result.promotions).to contain_exactly(cashier_waaoh_promotion)
      expect(result.lines.pluck(:label)).not_to include("ARTICLE MANQUANT", "ARTICLE RETIRE")
      expect(result.warnings).to contain_exactly(selfscan_warning("Nouveau scan incorrect"))
    end

    it "differentiates Waaoh cash credit and debit summary lines" do
      result = described_class.new(text: cashier_text_with_waaoh_cash_events).call

      expect(result.promotions).to contain_exactly(waaoh_cash_credit_promotion, waaoh_cash_debit_promotion)
    end
  end

  def parse_fixture(path)
    described_class.new(text: Rails.root.join("spec/fixtures/files", path).read).call
  end

  def cashier_text_with_scan_corrections
    Rails.root.join("spec/fixtures/files/parser/auchan_paper_v1_cashier.txt").read.sub(
      "TOT. ARTICLES ELIGIBLES TR",
      "-ARTICLE MANQUANT 1,20\n+ARTICLE RETIRE 2,30\nNouveau scan incorrect\nTOT. ARTICLES ELIGIBLES TR"
    )
  end

  def cashier_text_with_waaoh_cash_events
    Rails.root.join("spec/fixtures/files/parser/auchan_paper_v1_cashier.txt").read.sub(
      "ARTICLE TRONQUE EXTRA.. 0,40",
      "Crédit du jour : 0,40\nDébit du jour : 0,15"
    )
  end

  def cashier_receipt_attributes
    {
      parser_format: "auchan.paper.v1",
      register_number: "101",
      ticket_number: "12345",
      cashier_code: "9999",
      total_cents: 500,
      declared_article_count: 3,
      parser_status: "parsed"
    }
  end

  def selfscan_receipt_attributes
    {
      total_cents: 1_350,
      declared_article_count: 3,
      parser_status: "needs_review"
    }
  end

  def cashier_tr_line
    hash_including(
      position: 1,
      raw_text: "*ARTICLE TRONQUE.. 2,00",
      label: "ARTICLE TRONQUE",
      label_truncated: true,
      quantity: BigDecimal("1"),
      total_cents: 200,
      tr_eligible: true,
      kind: "item"
    )
  end

  def cashier_quantity_line
    hash_including(
      position: 2,
      raw_text: "PRODUIT QUANTITE 2*1,50 3,00",
      label: "PRODUIT QUANTITE",
      quantity: BigDecimal("2"),
      unit_price_cents: 150,
      total_cents: 300,
      tr_eligible: false,
      kind: "item"
    )
  end

  def cashier_payment
    hash_including(raw_label: "CARTE BANCAIRE", category: "bank_card", amount_cents: 500)
  end

  def cashier_waaoh_promotion
    {
      program: "auchan_waaoh",
      unit: "euro_cents",
      delta: 40,
      label: "ARTICLE TRONQUE EXTRA",
      kind: "loyalty_cash_credit",
      linked_line_position: 1,
      linking_method: "parser_inferred"
    }
  end

  def waaoh_cash_credit_promotion
    {
      program: "auchan_waaoh",
      unit: "euro_cents",
      delta: 40,
      label: "Crédit du jour",
      kind: "loyalty_cash_credit",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def waaoh_cash_debit_promotion
    {
      program: "auchan_waaoh",
      unit: "euro_cents",
      delta: -15,
      label: "Débit du jour",
      kind: "loyalty_cash_debit",
      linked_line_position: nil,
      linking_method: "unallocated"
    }
  end

  def selfscan_item_line
    hash_including(label: "ARTICLE SIMPLE", tr_eligible: true, section_label: "Selfscan", kind: "item")
  end

  def selfscan_discounted_item_line
    hash_including(label: "ARTICLE REMISE", unit_price_cents: 500, total_cents: 500, section_label: "Articles avec Remise")
  end

  def selfscan_discount_line
    hash_including(label: "30% DE REMISE IM", total_cents: -150, kind: "discount")
  end

  def selfscan_cash_payment
    hash_including(raw_label: "ESPECES", category: "cash", amount_cents: 200)
  end

  def selfscan_card_payment
    hash_including(raw_label: "CARTE BANCAIRE", category: "bank_card", amount_cents: 1_150)
  end

  def selfscan_warning(detail)
    {
      code: "auchan_selfscan_warning",
      validator: nil,
      detail: detail,
      value: nil
    }
  end
end
