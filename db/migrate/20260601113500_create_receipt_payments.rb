class CreateReceiptPayments < ActiveRecord::Migration[8.1]
  def change
    create_enum :receipt_payment_category, %w[ bank_card tickets_restaurant cash web other ]

    create_table :receipt_payments do |t|
      t.references :receipt, null: false, foreign_key: true
      t.integer :position, null: false
      t.text :raw_label, null: false
      t.enum :category, enum_type: :receipt_payment_category, null: false
      t.integer :amount_cents, null: false

      t.timestamps
    end

    add_index :receipt_payments, [ :receipt_id, :position ], unique: true
    add_check_constraint :receipt_payments, "amount_cents > 0", name: "receipt_payments_amount_cents_positive"
  end
end
