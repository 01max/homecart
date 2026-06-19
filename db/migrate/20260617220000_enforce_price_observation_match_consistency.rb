class EnforcePriceObservationMatchConsistency < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE FUNCTION enforce_price_observation_match_consistency()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        matching_decision receipt_line_matches%ROWTYPE;
      BEGIN
        SELECT *
        INTO matching_decision
        FROM receipt_line_matches
        WHERE id = NEW.receipt_line_match_id;

        IF NOT FOUND THEN
          RETURN NEW;
        END IF;

        IF matching_decision.status <> 'confirmed' THEN
          RAISE EXCEPTION 'price observations require confirmed receipt-line matches'
            USING ERRCODE = 'check_violation';
        END IF;

        IF ROW(matching_decision.receipt_line_id, matching_decision.product_variant_id)
          IS DISTINCT FROM ROW(NEW.receipt_line_id, NEW.product_variant_id) THEN
          RAISE EXCEPTION 'price observations must match their receipt-line match'
            USING ERRCODE = 'check_violation';
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER price_observations_match_consistency
      BEFORE INSERT OR UPDATE OF receipt_line_match_id, receipt_line_id, product_variant_id
      ON price_observations
      FOR EACH ROW
      EXECUTE FUNCTION enforce_price_observation_match_consistency();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS price_observations_match_consistency ON price_observations"
    execute "DROP FUNCTION IF EXISTS enforce_price_observation_match_consistency()"
  end
end
