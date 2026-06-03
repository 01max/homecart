require "rails_helper"

RSpec.describe ReceiptIngestion::DetectDuplicateService do
  def build_candidate_receipt(
    store: create_store,
    purchased_at: Time.zone.local(2026, 6, 1, 12, 30, 0),
    register_number: "101",
    ticket_number: "12345",
    total_cents: 500,
    parser_warnings: []
  )
    source_document = create_source_document(store: store)
    text_extraction = create_text_extraction(source_document: source_document)

    Receipt.new(
      store: store,
      source_document: source_document,
      text_extraction: text_extraction,
      parser_format: "leclerc.paper.v1",
      purchased_at: purchased_at,
      register_number: register_number,
      ticket_number: ticket_number,
      total_cents: total_cents,
      declared_article_count: 1,
      parser_status: "parsed",
      parser_warnings: parser_warnings
    )
  end

  def create_existing_receipt(store:, purchased_at:, total_cents: 500)
    create_receipt(
      store: store,
      purchased_at: purchased_at,
      total_cents: total_cents,
      parser_status: "parsed"
    )
  end

  def create_existing_exact_duplicate(store:, purchased_at:)
    create_existing_receipt(store: store, purchased_at: purchased_at).tap do |receipt|
      receipt.update!(register_number: "101", ticket_number: "12345")
    end
  end

  def build_exact_duplicate_pair
    store = create_store
    purchased_at = Time.zone.local(2026, 6, 1, 12, 30, 0)

    [
      create_existing_exact_duplicate(store: store, purchased_at: purchased_at),
      build_candidate_receipt(store: store, purchased_at: purchased_at)
    ]
  end

  def build_suspected_duplicate_pair
    store = create_store

    [
      create_existing_receipt(store: store, purchased_at: Time.zone.local(2026, 6, 1, 9, 15, 0)),
      build_candidate_receipt(
        store: store,
        purchased_at: Time.zone.local(2026, 6, 1, 18, 45, 0),
        ticket_number: "99999",
        total_cents: 500
      )
    ]
  end

  def build_candidate_with_stale_suspected_duplicate(store)
    parser_warning = { code: "parser_notice", validator: nil, detail: "Parser noticed something", value: nil }
    stale_warning = { code: "suspected_duplicate", validator: nil, detail: "Old duplicate", value: nil }

    build_candidate_receipt(
      store: store,
      purchased_at: Time.zone.local(2026, 6, 1, 18, 45, 0),
      total_cents: 500,
      parser_warnings: [ parser_warning, stale_warning ]
    )
  end

  def expect_duplicate_error(candidate, duplicate)
    expect do
      described_class.call(receipt: candidate)
    end.to raise_error(
      described_class::DuplicateReceiptError,
      /#{Regexp.escape(duplicate.id)}/
    )
  end

  def suspected_duplicate_warning_for(receipt)
    {
      "code" => "suspected_duplicate",
      "validator" => nil,
      "detail" => "Possible duplicate of receipt #{receipt.id}",
      "value" => nil
    }
  end

  it "rejects an exact composite duplicate and points to the existing receipt" do
    existing_receipt, candidate = build_exact_duplicate_pair

    expect_duplicate_error(candidate, existing_receipt)
  end

  it "adds a structured suspected-duplicate warning for a same-store same-day same-total receipt" do
    existing_receipt, candidate = build_suspected_duplicate_pair

    result = described_class.call(receipt: candidate)

    expect(result.suspected_duplicate).to eq(existing_receipt)
    expect(candidate.parser_warnings).to contain_exactly(suspected_duplicate_warning_for(existing_receipt))
  end

  it "preserves other parser warnings while replacing a stale suspected-duplicate warning" do
    store = create_store
    existing_receipt = create_existing_receipt(store: store, purchased_at: Time.zone.local(2026, 6, 1, 9, 15, 0))
    candidate = build_candidate_with_stale_suspected_duplicate(store)

    described_class.call(receipt: candidate)

    expect(candidate.parser_warnings).to contain_exactly(
      a_hash_including("code" => "parser_notice", "detail" => "Parser noticed something"),
      suspected_duplicate_warning_for(existing_receipt)
    )
  end

  it "does not flag receipts that only match on a different date" do
    store = create_store
    create_existing_receipt(store: store, purchased_at: Time.zone.local(2026, 6, 1, 9, 15, 0))
    candidate = build_candidate_receipt(store: store, purchased_at: Time.zone.local(2026, 6, 2, 9, 15, 0), total_cents: 500)

    result = described_class.call(receipt: candidate)

    expect(result.suspected_duplicate).to be_nil
    expect(candidate.parser_warnings).to be_empty
  end
end
