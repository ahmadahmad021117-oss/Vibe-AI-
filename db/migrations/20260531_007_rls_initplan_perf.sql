-- Optimize RLS policies for the auth_rls_initplan linter (0003).
--
-- Every "own row" policy compared `auth.uid()` directly, which Postgres
-- re-evaluates once per scanned row. Wrapping it in a scalar subquery
-- `(select auth.uid())` lets the planner evaluate it a single time per query.
-- Behaviour is identical — only the query plan changes — so this is a pure
-- performance fix ahead of scale.

-- profiles (keyed on id, not user_id)
alter policy "profiles_select_own" on public.profiles using ((select auth.uid()) = id);
alter policy "profiles_insert_own" on public.profiles with check ((select auth.uid()) = id);
alter policy "profiles_update_own" on public.profiles using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
alter policy "profiles_delete_own" on public.profiles using ((select auth.uid()) = id);

-- goals
alter policy "goals_select_own" on public.goals using ((select auth.uid()) = user_id);
alter policy "goals_insert_own" on public.goals with check ((select auth.uid()) = user_id);
alter policy "goals_update_own" on public.goals using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "goals_delete_own" on public.goals using ((select auth.uid()) = user_id);

-- weight_logs
alter policy "weight_logs_select_own" on public.weight_logs using ((select auth.uid()) = user_id);
alter policy "weight_logs_insert_own" on public.weight_logs with check ((select auth.uid()) = user_id);
alter policy "weight_logs_update_own" on public.weight_logs using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "weight_logs_delete_own" on public.weight_logs using ((select auth.uid()) = user_id);

-- targets
alter policy "targets_select_own" on public.targets using ((select auth.uid()) = user_id);
alter policy "targets_insert_own" on public.targets with check ((select auth.uid()) = user_id);
alter policy "targets_update_own" on public.targets using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "targets_delete_own" on public.targets using ((select auth.uid()) = user_id);

-- food_logs
alter policy "food_logs_select_own" on public.food_logs using ((select auth.uid()) = user_id);
alter policy "food_logs_insert_own" on public.food_logs with check ((select auth.uid()) = user_id);
alter policy "food_logs_update_own" on public.food_logs using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "food_logs_delete_own" on public.food_logs using ((select auth.uid()) = user_id);

-- activity_syncs
alter policy "activity_syncs_select_own" on public.activity_syncs using ((select auth.uid()) = user_id);
alter policy "activity_syncs_insert_own" on public.activity_syncs with check ((select auth.uid()) = user_id);
alter policy "activity_syncs_update_own" on public.activity_syncs using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "activity_syncs_delete_own" on public.activity_syncs using ((select auth.uid()) = user_id);

-- saved_meals
alter policy "saved_meals_select_own" on public.saved_meals using ((select auth.uid()) = user_id);
alter policy "saved_meals_insert_own" on public.saved_meals with check ((select auth.uid()) = user_id);
alter policy "saved_meals_update_own" on public.saved_meals using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy "saved_meals_delete_own" on public.saved_meals using ((select auth.uid()) = user_id);

-- entitlements (select-only for the user; rows are written by the RevenueCat webhook via service role)
alter policy "entitlements_select_own" on public.entitlements using ((select auth.uid()) = user_id);

-- scan_attempts (select-only for the user; rows are written by the check_and_record_scan security-definer function)
alter policy "scan_attempts_select_own" on public.scan_attempts using ((select auth.uid()) = user_id);
