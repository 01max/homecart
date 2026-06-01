require "rails_helper"

RSpec.describe ReceiptPayment do
  it "belongs to a receipt" do
    receipt = create_receipt
    payment = create_receipt_payment(receipt: receipt)

    expect(receipt.receipt_payments).to contain_exactly(payment)
  end

  it "declares payment categories" do
    payment = create_receipt_payment

    expect(payment.bank_card?).to be(true)
    expect(described_class.categories.keys).to include("tickets_restaurant", "web", "other")
  end

  it "requires unique positions within a receipt" do
    payment = create_receipt_payment
    duplicate = create_receipt_payment(receipt: payment.receipt, position: 2)
    duplicate.position = payment.position

    expect(duplicate).not_to be_valid
  end

  it "requires a positive integer amount" do
    payment = create_receipt_payment.tap { |record| record.amount_cents = 0 }

    expect(payment).not_to be_valid
  end
end
