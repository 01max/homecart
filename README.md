# homecart

Personal Rails app for automating grocery shopping.

Starting for v1 with ingestion of paper, PDF, and Drive receipts, building toward normalisation, spending analytics, price comparison, and more.

Single-user, self-hosted.

## Stack

Ruby 4.0.5, Rails 8.1.3, Postgres 16, Solid Queue, Active Storage (disk), Tesseract + `pdftotext`, Hotwire, Tailwind, RSpec.

## Setup

This project is just bootstrapped. The Docker-based one-command setup lands in the next sub-task.

For local Ruby development:

```sh
bundle install
bundle exec rails db:prepare
bundle exec rspec
```
