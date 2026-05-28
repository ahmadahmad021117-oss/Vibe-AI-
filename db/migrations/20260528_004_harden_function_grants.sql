-- 20260528_004_harden_function_grants.sql
-- Security hardening surfaced by Supabase advisors 0028/0029 (SECURITY DEFINER
-- functions executable by anon/authenticated) and 0011 (mutable search_path).
--
-- The scan RPCs are only ever called by the analyze-food edge function using the
-- service_role key, which keeps its explicit EXECUTE grant. handle_new_user runs
-- solely as an auth.users trigger (EXECUTE grants are not consulted for triggers).
-- Removing anon/authenticated EXECUTE closes the direct PostgREST /rpc surface
-- without affecting the app.

REVOKE EXECUTE ON FUNCTION public.check_and_record_scan(uuid, integer) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.mark_scan_outcome(uuid, text) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

ALTER FUNCTION public.set_updated_at() SET search_path = public;
