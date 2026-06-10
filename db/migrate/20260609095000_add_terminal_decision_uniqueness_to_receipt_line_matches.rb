class AddTerminalDecisionUniquenessToReceiptLineMatches < ActiveRecord::Migration[8.1]
  def change
    add_index :receipt_line_matches,
              :receipt_line_id,
              unique: true,
              where: "status IN ('confirmed', 'ignored')",
              name: "index_receipt_line_matches_on_terminal_decision"
  end
end
