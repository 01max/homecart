class AddPointsConsumptionToReceiptPromotionKind < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      ALTER TYPE receipt_promotion_kind
      ADD VALUE IF NOT EXISTS 'points_consumption'
      AFTER 'points_accrual'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
