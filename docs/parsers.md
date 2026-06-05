# Parser Guide

Homecart parsers turn one immutable `TextExtraction.text` value into a structured parser result that receipt-ingestion services persist as a `Receipt`, `ReceiptLine`, `ReceiptPromotion`, and `ReceiptPayment` graph. Parsers do not save records, enqueue jobs, mutate source evidence, or decide which store the receipt belongs to.

## Parser Anatomy

A parser class lives under `lib/parser/<brand>/<channel>/<version>.rb`, inherits directly or indirectly from `Parser::Base`, declares a `FORMAT` constant from `Parser::Registry::FORMATS`, and registers itself with `Parser::Registry`.

For example, `leclerc.paper.v2` is implemented by `Parser::Leclerc::Paper::V2` in `lib/parser/leclerc/paper/v2.rb`.

Concrete parsers provide format grammar only:

- `receipt_attributes` returns receipt-level attributes such as `parser_format`, `purchased_at`, `total_cents`, and `declared_article_count`.
- `parsed_lines` returns line attributes before positions are assigned. Base assigns receipt-order positions.
- `payment_attributes` returns ordered payment rows.
- `promotion_attributes` returns loyalty, coupon, points, or immediate-discount rows when the format has them.
- `after_parse(result)` is optional and should be reserved for format-local post-processing, such as VAT enrichment.

Use shared helpers from `Parser::Base` for cents, decimals, label normalization, French month parsing, payment category mapping, promotion attributes, and linked-line lookup. When a retailer/channel has repeated grammar, extract a format-family base such as `Parser::Leclerc::Paper::Base` or `Parser::MagasinsU::Paper::Base`; keep the top-level `Parser::Base` generic.

## `Parser::Base` Contract

`Parser::Base` provides the result envelope:

```ruby
Parser::Base::Result.new(
  receipt: receipt_attributes,
  lines: line_attributes,
  promotions: promotion_attributes,
  payments: payment_attributes,
  warnings: warnings
)
```

It also owns the three shared validators:

- `validate_totals_sum`
- `validate_article_count`
- `validate_payments_sum`

Base contains no format-specific logic. Format classes must never modify `Parser::Base` to make one receipt format pass. Add format behavior in the concrete parser or in a retailer/channel family base. This convention keeps Base reviewable as new parsers are added in v1.x.

## Monetary Rounding Tolerance

`validate_totals_sum` and `validate_payments_sum` pass when the discrepancy is within `Parser::Base::MONETARY_TOLERANCE_CENTS`, currently +/- 1 cent.

Do not tighten this tolerance for a new parser. French registers can round at the receipt level rather than the individual line level, so sub-cent line math may produce a one-cent reconciliation difference while the receipt is still valid.

The article-count validator is exact. It sums `quantity` only for item lines with `unit_of_measure: "piece"`; item lines with another unit, such as `kg`, count as one article.

## Structured `parser_warnings`

Warnings persisted to `Receipt#parser_warnings` are structured hashes with exactly four keys:

```ruby
{
  code: "totals_sum_mismatch",
  validator: "validate_totals_sum",
  detail: "Line totals differ from receipt total by 2 cents",
  value: 2
}
```

- `code` is the stable machine identifier.
- `validator` is the validator method name, or `nil` for non-validator warnings.
- `detail` is the human-readable review message.
- `value` is a numeric discrepancy or `nil`.

Append warnings through `add_warning`. It validates the shape immediately through `Parser::Base.validate_warning!`. Do not append strings, ad-hoc hashes, or locale keys to `warnings`.

## Format Naming

Format ids use the dotted `brand.channel.version` convention:

```text
auchan.paper.v1
leclerc.paper.v2
leclerc.web.v1
u.paper.v2
```

The Ruby constant mirrors the same hierarchy under the singular `Parser` namespace:

```text
Parser::Auchan::Paper::V1
Parser::Leclerc::Paper::V2
Parser::Leclerc::Web::V1
Parser::MagasinsU::Paper::V2
```

`Parser::Registry` validates both sides: the format must exist in `Parser::Registry::FORMATS`, and the registering class name must match the expected namespace. The `u` brand is mapped to `MagasinsU` by `Parser::Registry::BRAND_CONSTANT_NAMES`.

Parser formats are also PostgreSQL enum values on `SourceDocument` and `Receipt`, so adding a format requires a migration as well as Ruby code.

## Shipped Formats

| Format | Parser | Example fixtures | Notes |
| --- | --- | --- | --- |
| `auchan.paper.v1` | `Parser::Auchan::Paper::V1` | `auchan_paper_v1_cashier.txt`, `auchan_paper_v1_selfscan.txt` | Cashier and Selfscan receipts share one parser. Handles dashed item sections, Selfscan markers, discount sections, leading `*` Tickets Restaurant eligibility, truncated `..` labels, Waaoh credit, VAT, and payments. |
| `leclerc.paper.v1` | `Parser::Leclerc::Paper::V1` | `leclerc_paper_v1_with_sections.txt`, `leclerc_paper_v1_without_sections.txt` | Old POS firmware. Item lines end at price, quantity can appear on a following line, section markers are optional, and the VAT table uses the legacy layout. |
| `leclerc.paper.v2` | `Parser::Leclerc::Paper::V2` | `leclerc_paper_v2_quantity_vat.txt`, `leclerc_paper_v2_sections_vat.txt` | New POS firmware. Item lines carry VAT codes and the bottom table maps codes to rates. Shares paper grammar with v1 through `Parser::Leclerc::Paper::Base`. |
| `leclerc.web.v1` | `Parser::Leclerc::Web::V1` | `leclerc_web_v1_drive.txt`, `leclerc_web_v1_click_collect.txt` | Drive and Click & Collect share one web parser. Handles single-pass items, web payments, and Drive delivery fee lines as `kind: "fee"`. |
| `u.paper.v1` | `Parser::MagasinsU::Paper::V1` | `u_paper_v1_weighted_quantity.txt`, `u_paper_v1_direct_items.txt` | Pre-OmniPOS Magasins U. Handles `>>>>` section markers, direct item lines, optional quantity or weighted-quantity follow-up lines, and single-card payment. |
| `u.paper.v2` | `Parser::MagasinsU::Paper::V2` | `u_paper_v2_multi_payment.txt`, `u_paper_v2_single_payment.txt` | OmniPOS Magasins U. Handles bare section words, mandatory quantity lines, mid-line `(T)` Tickets Restaurant markers, VAT code tables, and multi-payment receipts. |

Fixture files live under `spec/fixtures/files/parser/`. Parser specs live under `spec/lib/parser/` and should exercise at least two representative fixtures per format.

## Adding a New Format

1. Add a migration for the new `parser_format` enum value.
2. Add the dotted id to `Parser::Registry::FORMATS`.
3. Add the parser class under the matching namespace and path.
4. Set `FORMAT = Parser::Registry::FORMATS.fetch(:your_format_key)`.
5. Register the parser with `Parser::Registry.register(FORMAT, self)`.
6. Add anonymized text fixtures under `spec/fixtures/files/parser/`.
7. Add parser specs covering receipt attributes, line counts, line totals, promotions, payments, weighted quantity if relevant, warnings, and validator outcomes.
8. Add upload-form default hints only if store/profile heuristics should suggest the new format.
9. Run focused parser specs, then `bundle exec rspec`, `bundle exec rubocop`, and `bundle exec rails zeitwerk:check`.

## Service Boundaries

Keep parser classes focused on parsing text into structured attributes. Non-trivial workflows belong in `app/services`, and every service class name ends with `Service`.

Current receipt-ingestion service boundaries:

- `ReceiptIngestion::UploadService` owns content hash calculation, duplicate source lookup, source document creation, attachment, and extraction job enqueueing.
- `ReceiptIngestion::ExtractTextService`, `ExtractPdfService`, and `ExtractImageWithTesseractService` own extraction.
- `ReceiptIngestion::ParseService` looks up the parser, runs it, persists the result envelope, handles parser exceptions, and delegates validation/deduplication.
- `ReceiptIngestion::ValidateParseService` recomputes persisted validators and writes `parser_status` and `parser_warnings`.
- `ReceiptIngestion::DetectDuplicateService` owns strict and suspected duplicate checks.
- `ReceiptIngestion::FinalizeReviewService` marks reviewed receipts after server-side validators pass.
- `ReceiptIngestion::RerunParserService` replaces an existing parse from the latest successful extraction.
- `ReceiptIngestion::BroadcastProcessingStatusService` owns Turbo Stream status broadcasts.

Controllers and jobs should load records, call services, and render or enqueue. They should not hold parser persistence logic. Models should keep associations, enums, validations, scopes, and evidence immutability. Do not use model lifecycle callbacks for parser execution, job chaining, broadcasts, review finalization, or other workflow behavior.
