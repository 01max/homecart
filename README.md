# homecart

Personal Rails app for turning grocery receipts into durable, queryable data.

The long-term goal is grocery automation: preserve receipt history, normalize products, understand spending patterns, compare prices, and eventually help build shopping carts. The project is currently focused on French grocery receipts, immutable receipt evidence, and the catalogue layer that links reviewed receipt lines to user-curated product variants without rewriting the original observations.

Single-user, self-hosted, no authentication.

## Status

Implemented:

- Rails app with PostgreSQL, Hotwire, Tailwind, Active Storage, Solid Queue, RSpec, SimpleCov, RuboCop, Brakeman, and bundler-audit.
- Development Docker compose stack with Rails, PostgreSQL, and a Solid Queue worker, plus a separate production-shaped compose file for self-hosted runs.
- Receipt evidence models: `RetailBrand`, `Store`, `SourceDocument`, `TextExtraction`, `Receipt`, `ReceiptLine`, `ReceiptPromotion`, and `ReceiptPayment`.
- Immutable evidence guards for source documents and extraction records.
- Upload, extraction, parsing, duplicate detection, review finalization, parser rerun, and processing-status broadcast services.
- PDF text extraction through `pdftotext -layout`.
- Image OCR through `rtesseract`, currently tuned for French receipts.
- Parser registry and parser implementations for the known receipt corpus.
- Upload, source-document status, receipt listing, and side-by-side receipt review UI.
- Parser reruns from the review UI.
- Product catalogue screens for product brands, optional manufacturers, category trees, comparison units, products, variants, and alternative groups.
- Receipt-line matching workflows for grouped historical labels and receipt-specific review, including search, inline variant creation, confirmation, rejection, ignore, and bulk-confirm flows.
- Price observations derived from confirmed receipt-line matches.

Still in progress:

- End-to-end ingestion of the historical receipt corpus.
- Higher-level shopping-list, recommendation, scraping, and offer-validity workflows.

## Stack

- Ruby
- Rails
- PostgreSQL
- Solid Queue, Solid Cache, Solid Cable
- Active Storage on local disk
- Hotwire, Stimulus, Importmap, Tailwind, Propshaft
- Tesseract OCR through `rtesseract`, focused on French receipts for now
- `pdftotext -layout` from Poppler
- RSpec, SimpleCov, RuboCop, Brakeman, bundler-audit

## Domain Model

`SourceDocument` is the immutable uploaded receipt file. It stores the SHA-256 content hash, MIME type, store, parser format, ingestion time, and the Active Storage attachment.

`TextExtraction` records one extraction attempt against a source document. Successful records keep the extracted text and engine identifier. Failed records keep the engine and error message. Extraction records are append-only evidence.

`Receipt` is the structured parser result for a source document and text extraction. It stores receipt-level fields such as purchase time, ticket/register metadata, total, parser format, parser status, and structured parser warnings.

`ReceiptLine`, `ReceiptPromotion`, and `ReceiptPayment` keep the normalized observations from the receipt. `ReceiptLine` remains evidence: matching a line to a product does not change its raw text, label, quantity, unit price, or total.

`RetailBrand` is the store chain or retailer, such as E.Leclerc, Auchan, or Magasins U. `ProductBrand` is the brand printed on a product, such as Bio Village, Marque Repere, Andros, Coca-Cola, or Auchan. A product brand can optionally belong to a retail brand for private labels, but retailer identity and product identity stay separate.

`Manufacturer` is optional catalogue enrichment. Products can link to one when the information is useful, but product creation and receipt-line matching do not require it.

`Category` is a user-managed tree. Products require a category, categories can be created, renamed, moved, and deleted when unused, and the app prevents category cycles.

`Product` is the shopper-facing item under a product brand and category. `ProductVariant` is the concrete purchasable size, flavor, package, or barcode-level item that receipt lines match to. Variants can store optional barcode data plus structured comparison details such as package count, quantity value, and comparison unit.

`ProductAlternativeGroup` records explicit variant-level substitutions within a category. Memberships can distinguish equivalent variants from comparable or different-size variants, while product-level alternatives remain derived from variant memberships.

`ReceiptLineMatch` stores product-identification decisions separately from receipt lines. Suggested, confirmed, rejected, and ignored decisions keep provenance and review status without mutating v1 evidence. Confirmed matches create or update `PriceObservation` rows for the matched variant, store, purchase time, purchased quantity/unit, total price, pack unit price, and comparison-unit price when derivable.

## Parser Formats

Parser format IDs use the dotted `brand.channel.version` convention. Ruby constants mirror that shape under the singular `Parser` namespace.

The canonical format list lives in `lib/parser/registry.rb`. Parser classes live under `lib/parser/<brand>/<channel>/<version>.rb` and register themselves with `Parser::Registry`.

`Parser::Base` owns the common result envelope and validators:

- line totals must reconcile with the receipt total within 1 cent
- payment totals must reconcile with the receipt total within 1 cent
- declared article count must match item quantities when the source provides a count

Parser warnings are structured hashes with `code`, `validator`, `detail`, and `value`.

## Docker Bootstrap

From a fresh checkout with Docker installed, start the development app stack with one command:

```sh
docker compose up
```

The default compose file is development-shaped. It bind-mounts the repository into `/rails`, sets `RAILS_ENV=development`, runs the Tailwind watcher, and exposes Rails on <http://localhost:3000>. Code, route, view, and CSS changes are visible without rebuilding the image.

Open a development console:

```sh
docker compose exec app bundle exec rails console
```

Run the full RSpec suite in Docker:

```sh
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec
```

Run one spec file:

```sh
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec spec/models/receipt_line_spec.rb
```

Project-local shortcut:

```sh
bin/dcspec
bin/dcspec spec/models/receipt_line_spec.rb
```

`bin/dcspec` runs the same Docker-enclosed RSpec command and forwards any arguments to RSpec. It is a repository-local executable, not a shell alias, so it does not require changes to `~/.zshrc` and does not auto-load as bare `dcspec` in new terminal tabs.

Run RuboCop in Docker:

```sh
docker compose run --rm --no-deps -e RAILS_ENV=test app bundle exec rubocop
```

Run Zeitwerk check in Docker:

```sh
docker compose run --rm --no-deps -e RAILS_ENV=test app bundle exec rails zeitwerk:check
```

Docker may print orphan-container warnings during test runs. They are harmless unless you intentionally changed compose service names and want to clean old containers.

For a production-shaped self-hosted run, use the standalone production compose file:

```sh
docker compose -f docker-compose.prod.yml up --build
```

That file uses the baked production image, sets `RAILS_ENV=production`, exposes port 80 inside the container through Thruster, and does not bind-mount the source tree.

## Local Development

Install dependencies:

```sh
bundle install
```

Prepare the database:

```sh
bundle exec rails db:prepare
```

Start the local development server and Tailwind watcher:

```sh
bin/dev
```

Run tests locally:

```sh
bundle exec rspec
```

Run style and security checks:

```sh
bundle exec rubocop
bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bundle exec bundler-audit
bin/importmap audit
```

The generated `rails_helper` defaults `RAILS_ENV` to `test` only when the environment is unset. Docker commands above pass `-e RAILS_ENV=test` explicitly so they never inherit development or production.

## Seed Data

Retail brands and stores are loaded from YAML by `db/seeds.rb`.

The tracked `db/seeds/retail_locations.yml` is anonymized so the public repository does not expose real shopping locations. For local real data, create:

```text
db/seeds/retail_locations.local.yml
```

Use the same shape as the tracked seed file. The local file is ignored by git and takes precedence when present.

After adding or changing stores:

```sh
bundle exec rails db:seed
```

## Adding a Parser Format

Parser formats are both Ruby registry keys and PostgreSQL enum values. Keep the dotted `brand.channel.version` ID consistent everywhere.

1. Add a migration that adds the new value to the `parser_format` enum.
2. Add the dotted format to `Parser::Registry::FORMATS`.
3. Add a parser class under the matching namespace, for example `Parser::Leclerc::Paper::V3` for `leclerc.paper.v3`.
4. Register the class with `Parser::Registry`.
5. Add anonymized text fixtures under `spec/fixtures/files/parser/`.
6. Add parser specs covering receipt fields, lines, promotions, payments, and validator outcomes.
7. Add or update upload/review coverage if the new format needs new UI hints or defaults.
8. Run focused parser specs, then `bundle exec rspec` and `bundle exec rubocop`.

Parsers return structured attributes only; persistence belongs in receipt-ingestion services.
