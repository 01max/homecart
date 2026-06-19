class AddCategoryCycleGuard < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION prevent_category_cycle()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        cycle_exists boolean;
      BEGIN
        IF NEW.parent_id IS NULL THEN
          RETURN NEW;
        END IF;

        WITH RECURSIVE ancestors(id, parent_id) AS (
          SELECT categories.id, categories.parent_id
          FROM categories
          WHERE categories.id = NEW.parent_id

          UNION ALL

          SELECT categories.id, categories.parent_id
          FROM categories
          INNER JOIN ancestors ON categories.id = ancestors.parent_id
        )
        SELECT true
        INTO cycle_exists
        FROM ancestors
        WHERE ancestors.id = NEW.id
        LIMIT 1;

        IF COALESCE(cycle_exists, false) THEN
          RAISE EXCEPTION 'categories cannot contain cycles'
            USING ERRCODE = 'check_violation';
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER categories_prevent_cycle
      AFTER INSERT OR UPDATE OF parent_id
      ON categories
      FOR EACH ROW
      EXECUTE FUNCTION prevent_category_cycle();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS categories_prevent_cycle ON categories"
    execute "DROP FUNCTION IF EXISTS prevent_category_cycle()"
  end
end
