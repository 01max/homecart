class CreateSourceDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :source_documents do |t|
      t.string :content_hash, null: false
      t.string :mime_type, null: false
      t.datetime :ingested_at, null: false

      t.timestamps
    end

    add_index :source_documents, :content_hash, unique: true
  end
end
