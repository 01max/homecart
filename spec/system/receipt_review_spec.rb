require "rails_helper"

RSpec.describe "Receipt review", type: :system do
  let(:retail_brand) { create(:retail_brand, name: "E.Leclerc") }
  let(:store) { create(:store, retail_brand: retail_brand, location_name: "Villeneuve sur Lot", channel: "physical") }

  def create_reviewable_receipt
    receipt = create(
      :receipt,
      store: store,
      total_cents: 1_234,
      declared_article_count: 2,
      parser_status: "needs_review"
    )
    create(:receipt_line, receipt: receipt, position: 1, label: "First item", raw_text: "FIRST ITEM 5.00", total_cents: 500)
    create(:receipt_line, receipt: receipt, position: 2, label: "Second item", raw_text: "SECOND ITEM 7.34", total_cents: 700)
    create(:receipt_payment, receipt: receipt, position: 1, amount_cents: 1_234)
    receipt
  end

  def receipt_line_row(label)
    label_input = find(:css, %(input[data-receipt-validators-target~="lineLabel"][value="#{label}"]))
    label_input.ancestor("tr")
  end

  def set_line_total(label, total_cents)
    within receipt_line_row(label) do
      find(:css, %(input[data-receipt-validators-target~="lineTotal"])).set(total_cents)
    end
  end

  def mark_reviewed
    click_button I18n.t("receipts.edit.form.mark_reviewed")
  end

  def expect_totals_validator_rejection
    expect(page).to have_content(
      I18n.t(
        "receipts.mark_reviewed.errors.validators_failed",
        validators: I18n.t("receipts.edit.validators.totals_sum.label")
      )
    )
  end

  it "marks a needs-review receipt reviewed after fixing a line total" do
    receipt = create_reviewable_receipt

    visit edit_receipt_path(receipt)
    set_line_total("Second item", "734")
    mark_reviewed

    expect(page).to have_content(I18n.t("receipts.mark_reviewed.success"))
    expect(receipt.reload).to be_reviewed
    expect(receipt.receipt_lines.find_by!(label: "Second item").total_cents).to eq(734)
  end

  it "rejects marking a needs-review receipt reviewed when totals are invalid" do
    receipt = create_reviewable_receipt

    visit edit_receipt_path(receipt)
    mark_reviewed

    expect_totals_validator_rejection
    expect(receipt.reload).to be_needs_review
  end
end
