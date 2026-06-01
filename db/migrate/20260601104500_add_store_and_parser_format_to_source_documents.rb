class AddStoreAndParserFormatToSourceDocuments < ActiveRecord::Migration[8.1]
  PARSER_FORMATS = [
    "auchan.paper.v1",
    "leclerc.paper.v1",
    "leclerc.paper.v2",
    "leclerc.web.v1",
    "u.paper.v1",
    "u.paper.v2"
  ].freeze

  def change
    create_enum :parser_format, PARSER_FORMATS

    change_table :source_documents do |t|
      t.references :store, null: false, foreign_key: true
      t.enum :parser_format, enum_type: :parser_format, null: false
    end
  end
end
