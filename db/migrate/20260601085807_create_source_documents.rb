class CreateSourceDocuments < ActiveRecord::Migration[8.1]
  def change
    create_enum :source_document_mime_type, [ "application/pdf", "image/png", "image/jpeg" ]

    create_table :source_documents do |t|
      t.string :content_hash, null: false
      t.enum :mime_type, enum_type: :source_document_mime_type, null: false
      t.datetime :ingested_at, null: false

      t.timestamps
    end

    add_index :source_documents, :content_hash, unique: true
  end
end
