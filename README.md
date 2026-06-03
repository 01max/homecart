# homecart

Personal Rails app for turning grocery receipts into durable, queryable data.

The long-term goal is grocery automation: preserve receipt history, normalize products, understand spending patterns, compare prices, and eventually help build shopping carts. The project is currently focused on French grocery receipts and the ingestion foundation: storing original receipt files, extracting text, parsing known retailer formats, and keeping the raw evidence intact for later re-processing.

Single-user, self-hosted, no authentication.

## Status

Implemented:

- Rails app with PostgreSQL, Hotwire, Tailwind, Active Storage, Solid Queue, RSpec, SimpleCov, RuboCop, Brakeman, and bundler-audit.
- Production-oriented Docker image and compose stack with Rails, PostgreSQL, and a Solid Queue worker.
- Receipt evidence models: `RetailBrand`, `Store`, `SourceDocument`, `TextExtraction`, `Receipt`, `ReceiptLine`, `ReceiptPromotion`, and `ReceiptPayment`.
- Immutable evidence guards for source documents and extraction records.
- Upload and extraction services for PDFs and images.
- PDF text extraction through `pdftotext -layout`.
- Image OCR through `rtesseract`, currently tuned for French receipts.
- Parser registry and parser implementations for the known receipt corpus.

Still in progress:

- Persisting parser results from `TextExtraction` into receipts through a parse service/job.
- Upload, listing, and review UI.
- Parser reruns and human review workflow.
- End-to-end ingestion of the historical receipt corpus.

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

`ReceiptLine`, `ReceiptPromotion`, and `ReceiptPayment` keep the normalized observations from the receipt without trying to identify products yet. Product matching, categories, offers, and price comparison are intentionally deferred.

## Parser Formats

Parser format IDs use the dotted `brand.channel.version` convention. Ruby constants mirror that shape under the singular `Parser` namespace.

The canonical format list lives in `lib/parser/registry.rb`. Parser classes live under `lib/parser/<brand>/<channel>/<version>.rb` and register themselves with `Parser::Registry`.

`Parser::Base` owns the common result envelope and validators:

- line totals must reconcile with the receipt total within 1 cent
- payment totals must reconcile with the receipt total within 1 cent
- declared article count must match item quantities when the source provides a count

Parser warnings are structured hashes with `code`, `validator`, `detail`, and `value`.

## Docker

Start the app stack:

```sh
docker compose up
```

The Docker image and `app` service are production-shaped. They set `RAILS_ENV=production`, precompile assets, expose port 80 in the container, and run Rails through Thruster. That is useful for deployment-like runs, but it means ad hoc commands inherit production unless you override the environment.

Run the full test suite in Docker:

```sh
docker compose run --rm --no-deps -e RAILS_ENV=test -v /Users/maxime/Dev/homecart:/rails app bundle exec rspec
```

Run one spec file:

```sh
docker compose run --rm --no-deps -e RAILS_ENV=test -v /Users/maxime/Dev/homecart:/rails app bundle exec rspec spec/models/receipt_line_spec.rb
```

Project-local shortcut:

```sh
bin/dcspec
bin/dcspec spec/models/receipt_line_spec.rb
```

`bin/dcspec` runs the same Docker-enclosed RSpec command and forwards any arguments to RSpec. It is a repository-local executable, not a shell alias, so it does not require changes to `~/.zshrc` and does not auto-load as bare `dcspec` in new terminal tabs.

Run RuboCop in Docker:

```sh
docker compose run --rm --no-deps -e RAILS_ENV=test -v /Users/maxime/Dev/homecart:/rails app bundle exec rubocop
```

Run Zeitwerk check in Docker:

```sh
docker compose run --rm --no-deps -e RAILS_ENV=test -v /Users/maxime/Dev/homecart:/rails app bundle exec rails zeitwerk:check
```

Docker may print orphan-container warnings during test runs. They are harmless unless you intentionally changed compose service names and want to clean old containers.

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

The generated `rails_helper` defaults `RAILS_ENV` to `test` only when the environment is unset. If you run specs through the production Docker service, pass `-e RAILS_ENV=test`.

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

1. Add the dotted format to `Parser::Registry::FORMATS`.
2. Add a parser class under the matching namespace.
3. Register the class with `Parser::Registry`.
4. Add anonymized text fixtures under `spec/fixtures/files/parser/`.
5. Add parser specs covering receipt fields, lines, promotions, payments, and validator outcomes.
6. Run focused parser specs, then the broader suite.

Parsers return structured attributes only; persistence belongs in receipt-ingestion services.
