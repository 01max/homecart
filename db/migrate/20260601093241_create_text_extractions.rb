class CreateTextExtractions < ActiveRecord::Migration[8.1]
  def change
    create_table :text_extractions do |t|
      t.references :source_document, null: false, foreign_key: true
      t.string :engine, null: false
      t.text :text, null: false, default: ""
      t.datetime :ran_at, null: false
      t.boolean :success, null: false, default: false
      t.text :error_message

      t.timestamps
    end
  end
end
