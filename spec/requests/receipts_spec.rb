require "rails_helper"

RSpec.describe "Receipts", type: :request do
  let(:retail_brand) { create(:retail_brand, slug: "leclerc").tap { |brand| brand.update!(name: "E.Leclerc") } }
  let(:store) { create(:store, retail_brand: retail_brand, location_name: "Villeneuve sur Lot", channel: "physical") }

  def create_listed_receipt(parser_status:, purchased_at:, total_cents: 1_234)
    create(:receipt,
      store: store,
      parser_status: parser_status,
      purchased_at: purchased_at,
      total_cents: total_cents
    )
  end

  def receipt_rows
    response.body.scan(%r{<tr(?:\s[^>]*)?>.*?</tr>}m)
  end

  def dom_id(record, prefix)
    ActionView::RecordIdentifier.dom_id(record, prefix)
  end

  def create_filterable_receipts
    create_listed_receipt(parser_status: "parsed", purchased_at: 2.days.ago, total_cents: 1111)
    create_listed_receipt(parser_status: "needs_review", purchased_at: 1.day.ago, total_cents: 2_222)
    create_listed_receipt(parser_status: "reviewed", purchased_at: Time.current, total_cents: 3_333)
  end

  def expect_receipts_workbench(receipt)
    expect(response.body).to include("hc-filter-block", "hc-table-block", "hc-table--dense")
    expect(response.body).to include(I18n.t("receipts.index.workbench.heading"))
    expect(response.body).to include(%(href="/source_documents/#{receipt.source_document.id}"))
    expect(response.body).to include(%(href="/receipts/#{receipt.id}/edit"))
  end

  def expect_receipt_before(rows, first_receipt, second_receipt)
    expect(rows.index { |row| row.include?(formatted_total(first_receipt)) })
      .to be < rows.index { |row| row.include?(formatted_total(second_receipt)) }
  end

  def create_review_receipt
    source_document = create(:source_document, store: store)
    text_extraction = create(:text_extraction, source_document: source_document, text: "RAW LINE\nTOTAL 12,34")
    receipt = create(
      :receipt,
      store: store,
      source_document: source_document,
      text_extraction: text_extraction,
      purchased_at: Time.zone.local(2026, 6, 1, 9, 15),
      register_number: "101",
      ticket_number: "12345",
      cashier_code: "C12",
      total_cents: 1_234,
      declared_article_count: 2,
      parser_status: "needs_review"
    )
    create(:receipt_line, receipt: receipt, position: 1, label: "Original label", raw_text: "ORIGINAL RAW", total_cents: 1_234)
    receipt
  end

  def review_receipt_params
    {
      receipt: {
        purchased_at: "2026-06-02T10:30",
        register_number: "202",
        ticket_number: "54321",
        cashier_code: "D34",
        total_cents: "2345",
        declared_article_count: "4"
      }
    }
  end

  def review_receipt_line_params(receipt:, replacement_store:)
    edited_line, removed_line = receipt.receipt_lines.order(:position)
    {
      receipt: {
        store_id: replacement_store.id,
        receipt_lines_attributes: {
          "0" => {
            id: edited_line.id,
            position: "1",
            raw_text: "UPDATED RAW",
            label: "Updated label",
            quantity: "2",
            unit_of_measure: "piece",
            unit_price_cents: "250",
            total_cents: "500",
            kind: "item",
            tr_eligible: "1",
            section_label: "UPDATED SECTION"
          },
          "1" => { id: removed_line.id, _destroy: "1" },
          "2" => {
            position: "3",
            raw_text: "NEW RAW",
            label: "New label",
            quantity: "1",
            unit_of_measure: "kg",
            unit_price_cents: "345",
            total_cents: "345",
            kind: "fee",
            tr_eligible: "0",
            section_label: "NEW SECTION"
          }
        }
      }
    }
  end

  def review_receipt_promotion_and_payment_params(receipt:)
    edited_promotion, removed_promotion = receipt.receipt_promotions.order(:created_at)
    edited_payment, removed_payment = receipt.receipt_payments.order(:position)
    linked_line = receipt.receipt_lines.order(:position).first

    {
      receipt: {
        receipt_promotions_attributes: promotion_update_params(edited_promotion, removed_promotion, linked_line),
        receipt_payments_attributes: payment_update_params(edited_payment, removed_payment)
      }
    }
  end

  def promotion_update_params(edited_promotion, removed_promotion, linked_line)
    {
      "0" => {
        id: edited_promotion.id,
        program: "updated_program",
        unit: "vignette_count",
        delta: "3",
        label: "Updated promotion",
        linked_line_id: linked_line.id,
        kind: "points_accrual",
        linking_method: "user_confirmed"
      },
      "1" => { id: removed_promotion.id, _destroy: "1" },
      "2" => {
        program: "new_program",
        unit: "euro_cents",
        delta: "-150",
        label: "New promotion",
        linked_line_id: "",
        kind: "coupon",
        linking_method: "unallocated"
      }
    }
  end

  def payment_update_params(edited_payment, removed_payment)
    {
      "0" => {
        id: edited_payment.id,
        position: "1",
        raw_label: "UPDATED CARD",
        category: "bank_card",
        amount_cents: "700"
      },
      "1" => { id: removed_payment.id, _destroy: "1" },
      "2" => {
        position: "3",
        raw_label: "TR CARD",
        category: "tickets_restaurant",
        amount_cents: "534"
      }
    }
  end

  def review_receipt_line_params_with_blank_row(receipt)
    line = receipt.receipt_lines.sole
    {
      receipt: {
        receipt_lines_attributes: {
          "0" => {
            id: line.id,
            position: line.position.to_s,
            raw_text: line.raw_text,
            label: line.label,
            quantity: line.quantity.to_s,
            unit_of_measure: line.unit_of_measure,
            total_cents: line.total_cents.to_s,
            kind: line.kind,
            tr_eligible: "0"
          },
          "1" => {
            position: "2",
            raw_text: "",
            label: "",
            quantity: "1.0",
            unit_of_measure: "piece",
            unit_price_cents: "",
            total_cents: "",
            kind: "item",
            tr_eligible: "0",
            section_label: ""
          }
        }
      }
    }
  end

  def review_receipt_promotion_and_payment_params_with_blank_rows(receipt)
    {
      receipt: {
        receipt_promotions_attributes: {
          "0" => {
            program: "",
            unit: "euro_cents",
            delta: "",
            label: "",
            linked_line_id: "",
            kind: "loyalty_credit",
            linking_method: "unallocated"
          }
        },
        receipt_payments_attributes: {
          "0" => {
            position: "1",
            raw_label: "",
            category: "bank_card",
            amount_cents: ""
          }
        }
      }
    }
  end

  def prepare_valid_review_receipt(receipt)
    receipt.update!(declared_article_count: 1)
    create(:receipt_payment, receipt: receipt, position: 1, amount_cents: receipt.total_cents)
    receipt
  end

  def expect_review_page(receipt)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("hc-page-toolbar", "hc-page-actions", "hc-stack")
    expect(response.body).to include(I18n.t("receipts.edit.description", store: "E.Leclerc — Villeneuve sur Lot (physical)"))
    expect(response.body).to include(I18n.t("receipts.edit.actions.source_document"))
    expect(response.body).to include(source_document_path(receipt.source_document))
    expect(response.body).to include(I18n.t("receipts.edit.actions.back_to_index"))
    expect(response.body).to include("RAW LINE\nTOTAL 12,34")
    expect(response.body).to include("hc-evidence-block", "hc-detail-block", "hc-action-block")
    expect_review_form_validator_panel
    expect(response.body).to include(I18n.t("receipts.edit.form.heading"))
    expect(response.body).to include(I18n.t("receipts.edit.form.description"))
    expect(response.body).to include(I18n.t("receipts.edit.form.store"))
    expect(response.body).to include(I18n.t("receipts.edit.form.total_cents"))
    expect(response.body).to include(I18n.t("receipts.edit.form.action_hint"))
    expect(response.body).to include(I18n.t("receipts.edit.extraction.description", engine: receipt.text_extraction.engine))
    expect(response.body).to include(I18n.t("receipts.edit.lines.heading"))
    expect(response.body).to include(%(name="receipt[total_cents]"))
    expect(response.body).to include(%q(name="receipt[receipt_lines_attributes]))
    expect(response.body).to include("lg:grid-cols-2")
    expect(response.body).to include("min-w-[72rem]")
    expect(response.body).to include("hc-table-frame")
    expect(response.body).to include(I18n.t("receipts.edit.lines.tr_eligible"))
    expect(response.body).to include(I18n.t("receipts.edit.promotions.heading"))
    expect(response.body).to include(I18n.t("receipts.edit.payments.heading"))
    expect(response.body).to include(%q(name="receipt[receipt_promotions_attributes]))
    expect(response.body).to include(%q(name="receipt[receipt_payments_attributes]))
    expect(response.body).to include(I18n.t("receipts.edit.form.mark_reviewed"))
    expect(response.body).to include(mark_reviewed_receipt_path(receipt))
    expect(response.body).to include(I18n.t("receipts.edit.form.rerun_parser"))
    expect(response.body).to include(rerun_parser_receipt_path(receipt))
    expect(response.body).to include(%(name="receipt[parser_format]"))
    expect_review_evidence_to_be_read_only
  end

  def expect_review_evidence_to_be_read_only
    expect(response.body).not_to include(%(name="source_document[original_file]"))
    expect(response.body).not_to include(%(name="source_document[content_hash]"))
    expect(response.body).not_to include(%(name="source_document[mime_type]"))
    expect(response.body).not_to include(%(name="source_document[ingested_at]"))
    expect(response.body).not_to include(%(name="text_extraction[engine]"))
    expect(response.body).not_to include(%(name="text_extraction[text]"))
    expect(response.body).not_to include(%(name="text_extraction[ran_at]"))
    expect(response.body).not_to include(%(name="text_extraction[success]"))
    expect(response.body).not_to include(%(name="text_extraction[error_message]"))
  end

  def expect_review_form_validator_panel
    expect(response.body).to include(%(data-controller="receipt-validators"))
    expect(response.body).to include(%(data-receipt-validators-target="receiptTotal"))
    expect(response.body).to include(%(data-receipt-validators-target="declaredArticleCount"))
    expect(response.body).to include(%(data-receipt-validators-target="line"))
    expect(response.body).to include(%(data-receipt-validators-target="payment"))
    expect(response.body).to include(%(data-receipt-validators-target="totalsSumCard"))
    expect(response.body).to include(%(data-receipt-validators-target="articleCountCard"))
    expect(response.body).to include(%(data-receipt-validators-target="paymentsSumCard"))
    expect(response.body).to include(I18n.t("receipts.edit.validators.heading"))
    expect(response.body).to include(I18n.t("receipts.edit.validators.description"))
    expect(response.body).to include(I18n.t("receipts.edit.validators.totals_sum.label"))
    expect(response.body).to include(I18n.t("receipts.edit.validators.article_count.label"))
    expect(response.body).to include(I18n.t("receipts.edit.validators.payments_sum.label"))
  end

  def expect_receipt_to_be_updated(receipt)
    expect(response).to redirect_to(edit_receipt_path(receipt))
    expect(flash[:notice]).to eq(I18n.t("receipts.update.success"))
    expect(receipt.reload).to have_attributes(
      purchased_at: Time.zone.local(2026, 6, 2, 10, 30),
      register_number: "202",
      ticket_number: "54321",
      cashier_code: "D34",
      total_cents: 2_345,
      declared_article_count: 4
    )
  end

  def expect_turbo_frame_receipt_notice(receipt)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(id="#{dom_id(receipt, :review_form)}"))
    expect(response.body).to include(I18n.t("receipts.update.success"))
    expect(response.body).to include(%(aria-live="polite"))
  end

  def expect_receipt_lines_to_be_updated(receipt, replacement_store)
    receipt.reload
    edited_line = receipt.receipt_lines.find_by!(position: 1)
    new_line = receipt.receipt_lines.find_by!(position: 3)

    expect(receipt.store).to eq(replacement_store)
    expect(receipt.receipt_lines.count).to eq(2)
    expect(edited_line).to have_attributes(label: "Updated label", raw_text: "UPDATED RAW", total_cents: 500)
    expect(edited_line).to be_tr_eligible
    expect(new_line).to have_attributes(label: "New label", unit_of_measure: "kg", kind: "fee", total_cents: 345)
  end

  def expect_promotions_and_payments_to_be_updated(receipt)
    receipt.reload
    edited_promotion = receipt.receipt_promotions.find_by!(program: "updated_program")
    new_promotion = receipt.receipt_promotions.find_by!(program: "new_program")
    edited_payment = receipt.receipt_payments.find_by!(position: 1)
    new_payment = receipt.receipt_payments.find_by!(position: 3)

    expect(receipt.receipt_promotions.count).to eq(2)
    expect(edited_promotion).to have_attributes(unit: "vignette_count", delta: 3, kind: "points_accrual", linking_method: "user_confirmed")
    expect(edited_promotion.linked_line).to eq(receipt.receipt_lines.order(:position).first)
    expect(new_promotion).to have_attributes(unit: "euro_cents", delta: -150, kind: "coupon", linking_method: "unallocated")
    expect(new_promotion.linked_line).to be_nil
    expect(receipt.receipt_payments.count).to eq(2)
    expect(edited_payment).to have_attributes(raw_label: "UPDATED CARD", category: "bank_card", amount_cents: 700)
    expect(new_payment).to have_attributes(raw_label: "TR CARD", category: "tickets_restaurant", amount_cents: 534)
  end

  def expect_receipt_to_be_marked_reviewed(receipt, promotion)
    expect(response).to redirect_to(edit_receipt_path(receipt))
    expect(flash[:notice]).to eq(I18n.t("receipts.mark_reviewed.success"))
    expect(receipt.reload).to be_reviewed
    expect(promotion.reload).to be_linking_method_user_confirmed
  end

  def expect_mark_reviewed_to_be_rejected(receipt)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("receipts.edit.validators.article_count.label"))
    expect(response.body).to include(
      I18n.t(
        "receipts.mark_reviewed.errors.validators_failed",
        validators: I18n.t("receipts.edit.validators.article_count.label")
      )
    )
    expect(receipt.reload).to be_needs_review
  end

  def expect_rerun_parser_to_succeed(receipt)
    expect(response).to redirect_to(edit_receipt_path(receipt))
    expect(flash[:notice]).to eq(I18n.t("receipts.rerun_parser.success"))
  end

  def expect_rerun_parser_to_be_rejected(receipt)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(I18n.t("receipts.rerun_parser.errors.invalid_parser_format"))
    expect(receipt.reload).to be_needs_review
  end

  it "lists receipts newest first" do
    older_receipt = create_listed_receipt(parser_status: "parsed", purchased_at: 2.days.ago, total_cents: 1_111)
    newer_receipt = create_listed_receipt(parser_status: "needs_review", purchased_at: 1.day.ago, total_cents: 2_222)

    get receipts_path

    rows = receipt_rows
    expect(response).to have_http_status(:ok)
    expect_receipt_before(rows, newer_receipt, older_receipt)
    expect(response.body).to include("E.Leclerc — Villeneuve sur Lot (physical)")
    expect_receipts_workbench(newer_receipt)
  end

  it "filters receipts by parser status" do
    create_filterable_receipts

    get receipts_path, params: { parser_status: "needs_review" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("receipts.parser_statuses.needs_review"))
    expect(response.body).to include("22,22 €")
    expect(response.body).not_to include("11,11 €")
    expect(response.body).not_to include("33,33 €")
  end

  it "ignores unknown parser status filters" do
    create_listed_receipt(parser_status: "parsed", purchased_at: Time.current, total_cents: 1111)

    get receipts_path, params: { parser_status: "unknown" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("11,11 €")
  end

  it "renders the empty state" do
    get receipts_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(I18n.t("receipts.index.empty"))
  end

  it "renders the side-by-side review page with extracted text and receipt form" do
    receipt = create_review_receipt

    get edit_receipt_path(receipt)

    expect_review_page(receipt)
  end

  it "updates editable receipt header fields" do
    receipt = create_review_receipt

    patch receipt_path(receipt), params: review_receipt_params

    expect_receipt_to_be_updated(receipt)
  end

  it "renders visible save feedback for Turbo Frame receipt updates" do
    receipt = create_review_receipt
    headers = { "Turbo-Frame" => dom_id(receipt, :review_form) }

    patch receipt_path(receipt), params: review_receipt_params, headers: headers

    expect_turbo_frame_receipt_notice(receipt)
  end

  it "updates store and receipt lines through nested attributes" do
    receipt = create_review_receipt
    create(:receipt_line, receipt: receipt, position: 2, label: "Removed label")
    replacement_store = create(:store, retail_brand: retail_brand, location_name: "Other location", channel: "drive")

    patch receipt_path(receipt), params: review_receipt_line_params(receipt: receipt, replacement_store: replacement_store)

    expect_receipt_lines_to_be_updated(receipt, replacement_store)
  end

  it "updates receipt promotions and payments through nested attributes" do
    receipt = create_review_receipt
    line = receipt.receipt_lines.order(:position).first
    create(:receipt_promotion, receipt: receipt, linked_line: line, linking_method: "parser_inferred")
    create(:receipt_promotion, receipt: receipt)
    create(:receipt_payment, receipt: receipt, position: 1, amount_cents: 900)
    create(:receipt_payment, receipt: receipt, position: 2, amount_cents: 334)

    patch receipt_path(receipt), params: review_receipt_promotion_and_payment_params(receipt: receipt)

    expect_promotions_and_payments_to_be_updated(receipt)
  end

  it "marks a receipt reviewed when submitted edits satisfy every validator" do
    receipt = prepare_valid_review_receipt(create_review_receipt)
    line = receipt.receipt_lines.sole
    promotion = create(:receipt_promotion, receipt: receipt, linked_line: line, linking_method: "parser_inferred")

    patch mark_reviewed_receipt_path(receipt), params: { receipt: { total_cents: receipt.total_cents.to_s } }

    expect_receipt_to_be_marked_reviewed(receipt, promotion)
  end

  it "rejects marking reviewed when a validator fails" do
    receipt = create_review_receipt
    create(:receipt_payment, receipt: receipt, position: 1, amount_cents: receipt.total_cents)

    patch mark_reviewed_receipt_path(receipt), params: { receipt: { total_cents: receipt.total_cents.to_s } }

    expect_mark_reviewed_to_be_rejected(receipt)
  end

  it "delegates parser re-runs to the rerun parser service" do
    receipt = create_review_receipt
    allow(ReceiptIngestion::RerunParserService).to receive(:call)

    patch rerun_parser_receipt_path(receipt), params: { receipt: { parser_format: "u.paper.v2" } }

    expect(ReceiptIngestion::RerunParserService).to have_received(:call).with(receipt: receipt, parser_format: "u.paper.v2")
    expect_rerun_parser_to_succeed(receipt)
  end

  it "rejects parser re-runs with an unsupported parser format" do
    receipt = create_review_receipt
    allow(ReceiptIngestion::RerunParserService).to receive(:call)

    patch rerun_parser_receipt_path(receipt), params: { receipt: { parser_format: "unknown.format" } }

    expect(ReceiptIngestion::RerunParserService).not_to have_received(:call)
    expect_rerun_parser_to_be_rejected(receipt)
  end

  it "ignores the blank add-row when default controls submit values" do
    receipt = create_review_receipt

    patch receipt_path(receipt), params: review_receipt_line_params_with_blank_row(receipt)

    expect(response).to redirect_to(edit_receipt_path(receipt))
    expect(receipt.reload.receipt_lines.count).to eq(1)
  end

  it "ignores blank promotion and payment add-rows when default controls submit values" do
    receipt = create_review_receipt

    patch receipt_path(receipt), params: review_receipt_promotion_and_payment_params_with_blank_rows(receipt)

    expect(response).to redirect_to(edit_receipt_path(receipt))
    expect(receipt.reload.receipt_promotions.count).to eq(0)
    expect(receipt.receipt_payments.count).to eq(0)
  end

  def formatted_total(receipt)
    "#{receipt.total_cents / 100},#{receipt.total_cents % 100} €"
  end
end
