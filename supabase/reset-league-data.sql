-- ===========================================================================
-- Wipe the imported data for ONE league, so it can be re-imported clean.
--
--   League: 7f5a9813-43fa-4c4e-a068-12bed7129fe2  (Banks Prediction League)
--
-- DELETES:  predictions, fixtures, entrants  — for that league only.
-- KEEPS:    the league row itself, league_members (your admin role),
--           profiles, auth users, and every other league.
--
-- THIS CANNOT BE UNDONE. Run the "before" query first and make sure the
-- numbers are the ones you expect to lose.
--
-- Run in the Supabase SQL editor (Dashboard -> SQL -> New query), which runs
-- as `postgres` and bypasses RLS. Afterwards run supabase/import-live-sheet.sql.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- BEFORE — what you are about to delete, and what is being kept.
-- ---------------------------------------------------------------------------
select 'about to DELETE' as what,
       (select count(*) from public.predictions where league_id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid) as predictions,
       (select count(*) from public.fixtures    where league_id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid) as fixtures,
       (select count(*) from public.entrants    where league_id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid) as entrants
union all
select 'keeping',
       (select count(*) from public.leagues        where id        = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid),
       (select count(*) from public.league_members where league_id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid),
       (select count(*) from public.profiles);

-- ---------------------------------------------------------------------------
-- DELETE. Predictions go first and explicitly: they would cascade from either
-- fixtures or entrants (predictions.fixture_id / .entrant_id are both
-- `on delete cascade` in schema.sql), but deleting them by name means the row
-- count comes back and nothing depends on cascade behaviour being right.
--
-- Every statement is scoped by league_id, so no other league is touched.
-- ---------------------------------------------------------------------------
delete from public.predictions
where league_id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid;

delete from public.fixtures
where league_id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid;

delete from public.entrants
where league_id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid;

-- ---------------------------------------------------------------------------
-- AFTER — the first three must all be 0; the league and your membership must
-- still be there (1 and 1+). If entrants is not 0, something outside this
-- league id owns those rows.
-- ---------------------------------------------------------------------------
select (select count(*) from public.predictions    where league_id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid) as predictions_left,
       (select count(*) from public.fixtures       where league_id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid) as fixtures_left,
       (select count(*) from public.entrants       where league_id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid) as entrants_left,
       (select count(*) from public.leagues        where id        = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid) as league_kept,
       (select count(*) from public.league_members where league_id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid) as members_kept;
