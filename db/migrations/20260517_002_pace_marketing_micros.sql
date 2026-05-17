-- Adds:
--   * profiles.pace                       (Slow / Medium / Fast)
--   * profiles.marketing_email            (separate from auth email; user-confirmable)
--   * profiles.marketing_email_opt_in     (explicit GDPR-compliant consent)
--   * profiles.marketing_consent_at       (audit trail for consent)
--   * food_logs micronutrient totals      (vitamin D / B12 / C, magnesium, iron, zinc)
--
-- All RLS policies inherit from the parent tables — no new policies required.

set search_path = public;

-- ============================================================
-- Pace enum
-- ============================================================
do $$ begin
  create type pace_type as enum ('slow', 'medium', 'fast');
exception when duplicate_object then null; end $$;

-- ============================================================
-- profiles: pace + marketing consent
-- ============================================================
alter table profiles
  add column if not exists pace pace_type,
  add column if not exists marketing_email text,
  add column if not exists marketing_email_opt_in boolean not null default false,
  add column if not exists marketing_consent_at timestamptz;

-- Loose sanity check on marketing_email format. Allows null.
alter table profiles
  drop constraint if exists profiles_marketing_email_format;
alter table profiles
  add constraint profiles_marketing_email_format
  check (
    marketing_email is null
    or marketing_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'
  );

-- ============================================================
-- food_logs: micronutrient totals
-- ============================================================
alter table food_logs
  add column if not exists vitamin_d_mcg   numeric(8,2) check (vitamin_d_mcg   is null or vitamin_d_mcg   >= 0),
  add column if not exists vitamin_b12_mcg numeric(8,2) check (vitamin_b12_mcg is null or vitamin_b12_mcg >= 0),
  add column if not exists vitamin_c_mg    numeric(8,2) check (vitamin_c_mg    is null or vitamin_c_mg    >= 0),
  add column if not exists magnesium_mg    numeric(8,2) check (magnesium_mg    is null or magnesium_mg    >= 0),
  add column if not exists iron_mg         numeric(8,2) check (iron_mg         is null or iron_mg         >= 0),
  add column if not exists zinc_mg         numeric(8,2) check (zinc_mg         is null or zinc_mg         >= 0);
