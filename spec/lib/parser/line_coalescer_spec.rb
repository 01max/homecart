require "rails_helper"

RSpec.describe Parser::LineCoalescer do
  it "coalesces identical piece-item rows into one counted line" do
    lines = Array.new(6) { repeated_piece_line } + [ other_item_line ]

    expect(described_class.call(lines)).to contain_exactly(repeated_piece_result, other_item_line)
  end

  it "prefers the duplicate row whose total reconciles with quantity and unit price" do
    lines = [ unreconciled_discounted_item_line, reconciled_discounted_item_line, discount_line ]

    expect(described_class.call(lines)).to contain_exactly(reconciled_discounted_item_line, discount_line)
  end

  it "keeps duplicate-looking rows separate when totals differ without a reconciled unit total" do
    first_line = repeated_piece_line.merge(total_cents: 99)
    second_line = repeated_piece_line.merge(total_cents: 199)

    expect(described_class.call([ first_line, second_line ])).to contain_exactly(first_line, second_line)
  end

  def repeated_piece_line
    {
      raw_text: "*KIWI JAUNE PIECE 0,99",
      label: "KIWI JAUNE PIECE",
      label_truncated: false,
      quantity: BigDecimal("1"),
      unit_of_measure: "piece",
      unit_price_cents: nil,
      total_cents: 99,
      vat_rate_bp: nil,
      tr_eligible: true,
      section_label: "Selfscan",
      kind: "item"
    }
  end

  def repeated_piece_result
    repeated_piece_line.merge(
      quantity: BigDecimal("6"),
      unit_price_cents: 99,
      total_cents: 594
    )
  end

  def other_item_line
    {
      raw_text: "*POMME GALA TENROY 1,71",
      label: "POMME GALA TENROY",
      label_truncated: false,
      quantity: BigDecimal("1"),
      unit_of_measure: "piece",
      unit_price_cents: nil,
      total_cents: 171,
      vat_rate_bp: nil,
      tr_eligible: true,
      section_label: "Selfscan",
      kind: "item"
    }
  end

  def unreconciled_discounted_item_line
    discounted_item_line(section_label: "Selfscan", total_cents: 600)
  end

  def reconciled_discounted_item_line
    discounted_item_line(section_label: "Articles avec Remise", total_cents: 910)
  end

  def discounted_item_line(section_label:, total_cents:)
    {
      raw_text: "*MENGUY S PEANUT C.. 2*4,55 6,00",
      label: "MENGUY S PEANUT C",
      label_truncated: true,
      quantity: BigDecimal("2"),
      unit_of_measure: "piece",
      unit_price_cents: 455,
      total_cents: total_cents,
      vat_rate_bp: nil,
      tr_eligible: true,
      section_label: section_label,
      kind: "item"
    }
  end

  def discount_line
    {
      raw_text: "BEURRE DE CACAHU.. -3,10",
      label: "BEURRE DE CACAHU",
      label_truncated: true,
      quantity: BigDecimal("1"),
      unit_of_measure: "piece",
      unit_price_cents: nil,
      total_cents: -310,
      vat_rate_bp: nil,
      tr_eligible: false,
      section_label: "Articles avec Remise",
      kind: "discount"
    }
  end
end
