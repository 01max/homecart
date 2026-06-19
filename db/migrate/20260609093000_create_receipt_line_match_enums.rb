class CreateReceiptLineMatchEnums < ActiveRecord::Migration[8.1]
  def change
    create_enum :receipt_line_match_status, %w[ suggested confirmed rejected ignored ]
    create_enum :receipt_line_match_source, %w[ user heuristic ]
  end
end
