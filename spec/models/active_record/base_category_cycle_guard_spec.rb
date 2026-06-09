require "rails_helper"

RSpec.describe ActiveRecord::Base do
  def insert_category(id:, name:, parent_id: nil)
    quoted_parent_id = parent_id.nil? ? "NULL" : quote(parent_id)

    execute_in_savepoint(<<~SQL.squish)
      INSERT INTO categories (id, name, normalized_name, slug, parent_id, created_at, updated_at)
      VALUES (
        #{quote(id)},
        #{quote(name)},
        #{quote(name.downcase)},
        #{quote(name.downcase.tr(" ", "-"))},
        #{quoted_parent_id},
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
    SQL
  end

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end

  def reparent_category(id:, parent_id:)
    execute_in_savepoint(<<~SQL.squish)
      UPDATE categories
      SET parent_id = #{quote(parent_id)}
      WHERE id = #{quote(id)}
    SQL
  end

  let(:root_id) { SecureRandom.uuid }
  let(:child_id) { SecureRandom.uuid }
  let(:grandchild_id) { SecureRandom.uuid }

  before do
    insert_category(id: root_id, name: "Root")
    insert_category(id: child_id, name: "Child", parent_id: root_id)
    insert_category(id: grandchild_id, name: "Grandchild", parent_id: child_id)
  end

  it "allows moving a category under a non-descendant parent" do
    other_root_id = SecureRandom.uuid
    insert_category(id: other_root_id, name: "Other Root")

    expect { reparent_category(id: child_id, parent_id: other_root_id) }.not_to raise_error
  end

  it "rejects moving a category under its descendant" do
    expect { reparent_category(id: root_id, parent_id: grandchild_id) }
      .to raise_error(ActiveRecord::StatementInvalid, /categories cannot contain cycles/)
  end
end
