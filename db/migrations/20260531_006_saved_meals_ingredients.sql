-- Adds recipe detail to saved_meals: per-ingredient measurements + prep steps.
-- Both default to an empty array so existing rows stay valid.
--
--   ingredients_json — [{ "name", "quantity" (number), "unit" }, ...] for one serving
--   steps_json       — ["step 1", "step 2", ...]

set search_path = public;

alter table saved_meals
  add column if not exists ingredients_json jsonb not null default '[]'::jsonb,
  add column if not exists steps_json jsonb not null default '[]'::jsonb;
