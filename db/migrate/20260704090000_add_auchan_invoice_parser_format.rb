class AddAuchanInvoiceParserFormat < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      ALTER TYPE parser_format
      ADD VALUE IF NOT EXISTS 'auchan.invoice.v1'
      BEFORE 'auchan.paper.v1'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
