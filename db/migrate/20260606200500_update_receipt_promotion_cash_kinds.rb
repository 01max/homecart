class UpdateReceiptPromotionCashKinds < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      ALTER TYPE receipt_promotion_kind
      RENAME VALUE 'loyalty_credit' TO 'loyalty_cash_credit'
    SQL

    execute <<~SQL.squish
      ALTER TYPE receipt_promotion_kind
      ADD VALUE IF NOT EXISTS 'loyalty_cash_debit'
      AFTER 'loyalty_cash_credit'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
