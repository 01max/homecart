require "rails_helper"

RSpec.describe ReceiptLineMatching::SuggestMatchesService do
  subject(:suggestions) { described_class.call(receipt_line: receipt_line) }

  it "suggests variants from prior confirmed normalized labels without auto-confirming" do
    variant = confirmed_jambon_variant
    receipt_line = reviewed_line(label: "JAMBON BLANC 4 TRANCHES")

    expect do
      expect_prior_label_suggestion(receipt_line, variant)
    end.not_to change(ReceiptLineMatch.suggested, :count)
    expect(ReceiptLineMatch.confirmed.exists?(receipt_line: receipt_line)).to be(false)
  end

  it "persists suggestions only when requested" do
    variant = confirmed_jambon_variant
    receipt_line = reviewed_line(label: "JAMBON BLANC 4 TRANCHES")

    expect do
      expect_prior_label_suggestion(receipt_line, variant, persist: true)
    end.to change(ReceiptLineMatch.suggested, :count).by(1)
  end

  it "queries prior confirmations by normalized label snapshot" do
    variant = confirmed_jambon_variant
    receipt_line = reviewed_line(label: "JAMBON BLANC 4 TRANCHES")
    ReceiptLineMatch.confirmed.last.update_columns(label_snapshot: "Legacy mismatch")

    expect(described_class.call(receipt_line: receipt_line).map(&:product_variant)).to include(variant)
  end

  it "does not suggest prior confirmations with a different normalized label snapshot" do
    confirmed_jambon_variant
    receipt_line = reviewed_line(label: "JAMBON BLANC 4 TRANCHES")
    ReceiptLineMatch.confirmed.last.update!(normalized_label_snapshot: "legacy mismatch")

    expect(described_class.call(receipt_line: receipt_line).map(&:reason)).not_to include(:prior_confirmed_label)
  end

  it "suggests variants from fuzzy catalogue search" do
    variant = create_compote_variant
    receipt_line = reviewed_line(label: "compote bio village")

    expect(described_class.call(receipt_line: receipt_line).map(&:product_variant)).to include(variant)
  end

  it "does not return a variant rejected for the same line" do
    variant = create_compote_variant
    receipt_line = reviewed_line(label: "compote bio village")

    ReceiptLineMatching::RejectMatchService.call(receipt_line: receipt_line, product_variant: variant)

    expect(described_class.call(receipt_line: receipt_line).map(&:product_variant)).not_to include(variant)
  end

  def create_jambon_variant
    create_catalogue_variant(
      product_brand_name: "Maison Dupont",
      product_name: "Jambon blanc",
      variant_name: "4 tranches"
    )
  end

  def confirmed_jambon_variant
    create_jambon_variant.tap do |variant|
      prior_line = reviewed_line(label: "Jambon blanc 4 tranches")
      ReceiptLineMatching::ConfirmMatchService.call(receipt_line: prior_line, product_variant: variant)
    end
  end

  def expect_prior_label_suggestion(receipt_line, variant, **options)
    expect(described_class.call(receipt_line: receipt_line, **options).first).to have_attributes(
      product_variant: variant,
      reason: :prior_confirmed_label,
      confidence: 1.0
    )
  end

  def reviewed_line(label:)
    create(:receipt_line, receipt: create(:receipt, :reviewed), label: label)
  end

  def create_compote_variant
    create_catalogue_variant(
      product_brand_name: "Bio Village",
      product_name: "Compotes pomme",
      variant_name: "12 x 90g"
    )
  end

  def create_catalogue_variant(product_brand_name:, product_name:, variant_name:)
    product_brand = create(:product_brand, name: product_brand_name)
    product = create(:product, product_brand: product_brand, name: product_name)

    create(:product_variant, product: product, name: variant_name)
  end
end
