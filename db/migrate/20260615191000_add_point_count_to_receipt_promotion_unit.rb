class AddPointCountToReceiptPromotionUnit < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      ALTER TYPE receipt_promotion_unit
      ADD VALUE IF NOT EXISTS 'point_count'
      AFTER 'vignette_count'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
