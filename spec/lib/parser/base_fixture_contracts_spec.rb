require "rails_helper"

PARSER_FIXTURE_CONTRACTS = [
  {
    format: "auchan.paper.v1",
    parser: Parser::Auchan::Paper::V1,
    fixture: "auchan_paper_v1_cashier.txt",
    status: "parsed",
    line_count: 2,
    total_cents: 500,
    declared_article_count: 3,
    promotion_count: 1,
    warning_count: 0
  },
  {
    format: "auchan.paper.v1",
    parser: Parser::Auchan::Paper::V1,
    fixture: "auchan_paper_v1_selfscan.txt",
    status: "needs_review",
    line_count: 4,
    total_cents: 1_350,
    declared_article_count: 3,
    promotion_count: 0,
    warning_count: 2
  },
  {
    format: "leclerc.paper.v1",
    parser: Parser::Leclerc::Paper::V1,
    fixture: "leclerc_paper_v1_with_sections.txt",
    status: "parsed",
    line_count: 4,
    total_cents: 1_773,
    declared_article_count: 6,
    promotion_count: 0,
    warning_count: 0
  },
  {
    format: "leclerc.paper.v1",
    parser: Parser::Leclerc::Paper::V1,
    fixture: "leclerc_paper_v1_without_sections.txt",
    status: "parsed",
    line_count: 3,
    total_cents: 989,
    declared_article_count: 3,
    promotion_count: 3,
    warning_count: 0
  },
  {
    format: "leclerc.paper.v2",
    parser: Parser::Leclerc::Paper::V2,
    fixture: "leclerc_paper_v2_quantity_vat.txt",
    status: "parsed",
    line_count: 1,
    total_cents: 1_070,
    declared_article_count: 2,
    promotion_count: 0,
    warning_count: 0
  },
  {
    format: "leclerc.paper.v2",
    parser: Parser::Leclerc::Paper::V2,
    fixture: "leclerc_paper_v2_sections_vat.txt",
    status: "parsed",
    line_count: 3,
    total_cents: 1_700,
    declared_article_count: 5,
    promotion_count: 4,
    warning_count: 0
  },
  {
    format: "leclerc.web.v1",
    parser: Parser::Leclerc::Web::V1,
    fixture: "leclerc_web_v1_drive.txt",
    status: "parsed",
    line_count: 3,
    total_cents: 1_000,
    declared_article_count: 3,
    promotion_count: 0,
    warning_count: 0
  },
  {
    format: "leclerc.web.v1",
    parser: Parser::Leclerc::Web::V1,
    fixture: "leclerc_web_v1_click_collect.txt",
    status: "parsed",
    line_count: 1,
    total_cents: 9_490,
    declared_article_count: 1,
    promotion_count: 0,
    warning_count: 0
  },
  {
    format: "u.paper.v1",
    parser: Parser::MagasinsU::Paper::V1,
    fixture: "u_paper_v1_weighted_quantity.txt",
    status: "parsed",
    line_count: 3,
    total_cents: 1_027,
    declared_article_count: 4,
    promotion_count: 1,
    warning_count: 0
  },
  {
    format: "u.paper.v1",
    parser: Parser::MagasinsU::Paper::V1,
    fixture: "u_paper_v1_direct_items.txt",
    status: "parsed",
    line_count: 3,
    total_cents: 717,
    declared_article_count: 3,
    promotion_count: 1,
    warning_count: 0
  },
  {
    format: "u.paper.v2",
    parser: Parser::MagasinsU::Paper::V2,
    fixture: "u_paper_v2_multi_payment.txt",
    status: "parsed",
    line_count: 3,
    total_cents: 952,
    declared_article_count: 3,
    promotion_count: 0,
    warning_count: 0
  },
  {
    format: "u.paper.v2",
    parser: Parser::MagasinsU::Paper::V2,
    fixture: "u_paper_v2_single_payment.txt",
    status: "parsed",
    line_count: 2,
    total_cents: 810,
    declared_article_count: 2,
    promotion_count: 1,
    warning_count: 0
  }
]

RSpec.describe Parser::Base do
  it "keeps at least two fixture receipts per parser format" do
    counts_by_format = PARSER_FIXTURE_CONTRACTS.group_by { |contract| contract.fetch(:format) }

    expect(counts_by_format.values.map(&:size)).to all(be >= 2)
  end

  PARSER_FIXTURE_CONTRACTS.each do |contract|
    it "parses #{contract.fetch(:fixture)} as #{contract.fetch(:format)} with reconciled totals" do
      result = parse_contract_fixture(contract)

      expect_fixture_contract(result, contract)
    end
  end

  def parse_contract_fixture(contract)
    contract.fetch(:parser).new(
      text: Rails.root.join("spec/fixtures/files/parser", contract.fetch(:fixture)).read
    ).call
  end

  def expect_fixture_contract(result, contract)
    aggregate_failures do
      expect(result.receipt).to include(
        parser_format: contract.fetch(:format),
        parser_status: contract.fetch(:status),
        total_cents: contract.fetch(:total_cents),
        declared_article_count: contract.fetch(:declared_article_count)
      )
      expect(result.lines.size).to eq(contract.fetch(:line_count))
      expect(result.lines.sum { |line| line.fetch(:total_cents) }).to eq(contract.fetch(:total_cents))
      expect(result.payments.sum { |payment| payment.fetch(:amount_cents) }).to eq(contract.fetch(:total_cents))
      expect(result.promotions.size).to eq(contract.fetch(:promotion_count))
      expect(result.warnings.size).to eq(contract.fetch(:warning_count))
    end
  end
end
