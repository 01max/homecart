# homecart

Personal Rails app for automating grocery shopping.

Starting for v1 with ingestion of paper, PDF, and Drive receipts, building toward normalisation, spending analytics, price comparison, and more.

Single-user, self-hosted.

## Stack

Ruby 4.0.5, Rails 8.1.3, Postgres 16, Solid Queue, Active Storage (disk), Tesseract + `pdftotext`, Hotwire, Tailwind, RSpec.

## Setup

Start the app stack with Docker:

```sh
docker compose up
```

For local Ruby development:

```sh
bundle install
bundle exec rails db:prepare
bundle exec rspec
```

## Seed Data

Retail brands and stores are loaded from YAML by `db/seeds.rb`. The tracked file at `db/seeds/retail_locations.yml` is anonymised so the public repository does not expose real-world shopping locations.

For local real data, create `db/seeds/retail_locations.local.yml` with the same shape. That file is ignored by git and takes precedence when present. When a new brand or store appears in the receipt corpus, add it to your local YAML file and re-run:

```sh
bundle exec rails db:seed
```
