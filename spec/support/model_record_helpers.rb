require "securerandom"

module ModelRecordHelpers
  def create_retail_brand(slug: "retailer-#{SecureRandom.hex(4)}")
    RetailBrand.create!(name: "Retailer", slug: slug, aliases: [])
  end

  def create_store(
    retail_brand: create_retail_brand,
    location_name: "Location #{SecureRandom.hex(2)}",
    channel: "physical",
    identifiers: {}
  )
    Store.create!(retail_brand: retail_brand, location_name: location_name, channel: channel, identifiers: identifiers)
  end

  def create_source_document(
    store: create_store,
    content_hash: SecureRandom.hex(32),
    mime_type: "application/pdf",
    parser_format: "leclerc.paper.v1"
  )
    SourceDocument.create!(
      store: store,
      content_hash: content_hash,
      mime_type: mime_type,
      parser_format: parser_format,
      ingested_at: Time.current
    )
  end

  def create_text_extraction(source_document: create_source_document, success: true)
    TextExtraction.create!(
      source_document: source_document,
      engine: "pdftotext-layout",
      text: success ? "raw receipt text" : "",
      ran_at: Time.current,
      success: success,
      error_message: success ? nil : "extraction failed"
    )
  end

  def create_receipt(
    store: create_store,
    source_document: create_source_document(store: store),
    text_extraction: create_text_extraction(source_document: source_document),
    purchased_at: Time.current,
    total_cents: 1_234,
    declared_article_count: 2,
    parser_status: "needs_review",
    parser_warnings: []
  )
    Receipt.create!(
      store: store,
      source_document: source_document,
      text_extraction: text_extraction,
      parser_format: "leclerc.paper.v1",
      purchased_at: purchased_at,
      total_cents: total_cents,
      declared_article_count: declared_article_count,
      parser_status: parser_status,
      parser_warnings: parser_warnings
    )
  end

  def create_receipt_line(
    receipt: create_receipt,
    position: 1,
    quantity: 1,
    unit_of_measure: "piece",
    total_cents: 1_234,
    kind: "item"
  )
    ReceiptLine.create!(
      receipt: receipt,
      position: position,
      raw_text: "ITEM  12.34",
      label: "ITEM",
      label_truncated: false,
      quantity: quantity,
      unit_of_measure: unit_of_measure,
      total_cents: total_cents,
      tr_eligible: false,
      kind: kind
    )
  end

  def create_receipt_promotion(receipt: create_receipt, linked_line: nil, linking_method: "unallocated")
    ReceiptPromotion.create!(
      receipt: receipt,
      program: "loyalty",
      unit: "euro_cents",
      delta: 100,
      label: "Loyalty credit",
      linked_line: linked_line,
      kind: "loyalty_credit",
      linking_method: linking_method
    )
  end

  def create_receipt_payment(receipt: create_receipt, position: 1, amount_cents: 1_234)
    ReceiptPayment.create!(receipt: receipt, position: position, raw_label: "CARD", category: "bank_card", amount_cents: amount_cents)
  end

  def execute_in_savepoint(sql)
    ActiveRecord::Base.transaction(requires_new: true) do
      ActiveRecord::Base.connection.execute(sql)
    end
  end
end

RSpec.configure do |config|
  config.include ModelRecordHelpers
end
