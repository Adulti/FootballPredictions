-- ===========================================================================
-- One-time bulk import of the Excel LIVE SHEET into the Predictor database.
-- ---------------------------------------------------------------------------
-- Source: "Football Predictions League - Games 001-400 - LIVE SHEET.xlsx"
-- Generated: 2026-09-13 — do not hand-edit, regenerate instead.
--
-- RUN IT IN THE SUPABASE SQL EDITOR (Dashboard -> SQL -> New query).
-- Every table here has row level security with `to authenticated` policies that
-- require league admin; the SQL editor runs as `postgres`, which bypasses RLS.
-- This will NOT work through the anon key from the browser.
--
-- Idempotent: entrants and fixtures are inserted only when an identical row is
-- absent (neither table has a unique constraint to conflict on), and predictions
-- upsert on unique (fixture_id, entrant_id). Safe to run repeatedly.
--
-- Entrant and team names are matched case-insensitively and space-insensitively
-- (lower(btrim(...))), so a row you already had under a slightly different
-- spelling is matched rather than duplicated.
--
-- Contains 33 entrants, 47 fixtures (23 with results),
-- 1192 predictions.
--
-- Deliberately absent (a non-submission is the absence of a row, since
-- predictions.home_score / away_score are NOT NULL):
--   * tab 19 — skipped entirely, the sheet is broken and unnamed
--   * Jam Lilo United (Chris Adkins) — no prediction for games 32-47
--   * Correct Score Cartel (AI) — no prediction for games 32-47
--   * Forever Blowing Predictions (Matt Adkins) — no prediction for games 32-47
--   * Kins Killers (Paul Kinsella) — no prediction for games 32-47
--   * For Farkes Sake (George Oldroyd) — no prediction for games 32-47
--   * Don't Look Back Elanga (Mark Wilkinson) — no prediction for games 32-47
--   * Reece's Pieces (Harry Adkins) — no prediction for games 32-47
--   * Hammered Nan (Kay Adkins) — no prediction for games 32-47
--   * Wilksy's Warriors (Jason Wilks) — no prediction for games 32-47
--   * Taking The Mikel (Ria Merchant) — no prediction for games 32-47
--   * Banan Anan Doo Doo Doo Doo Doo (Liam Merchant) — no prediction for games 32-47
--   * Some Jaouen And Some You Lose (Gary Morgan) — no prediction for games 32-47
--   * Boksh-to-Boksh (Shabbir Boksh) — no prediction for games 32-47
--   * Nancy Drew Your Predictions (Nancy Sharma) — no prediction for games 32-47
--   * The Eagles Pitt Stop (Mirko Kola) — no prediction for games 32-47
--   * Weah Better Than This (Jonathan Snaith) — no prediction for games 41-47
--   * Victor Moses Lawn (Matthew Noble) — no prediction for games 8-15, 32-47
--   * SSC Napollie (Oliver Pocock) — no prediction for games 32-47
--   * Romans Rascals (Simon McNicholas) — no prediction for games 16-23
--   * Geordie Goal Getters (Matthew Newton) — no prediction for games 32-47
--   * Tricky Trees (James Seabury) — no prediction for games 32-47
--   * Blasterz (Aashique Ahmed) — no prediction for games 32-47
--   * Colly's Mags (Jordan Collington) — no prediction for games 32-47
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- >>> THE LEAGUE IS ADDRESSED BY ID, not by name:
--       7f5a9813-43fa-4c4e-a068-12bed7129fe2  (Banks Prediction League)
--
--     Nothing to find & replace. A name lookup that matches nothing yields an
--     EMPTY league CTE, and an insert joined to an empty CTE writes zero rows
--     and reports no error — so a single missed replacement silently skipped a
--     whole entrant. Only change the id below if you are importing into a
--     different league:  select id, name from public.leagues;
--
--     Each statement carries its own `with league as` clause rather than
--     sharing a temp table: the Supabase SQL editor commits each statement
--     separately, so anything session-scoped (a temp table, an explicit
--     begin/commit) is gone by the time the next statement runs. That also
--     means this script is NOT atomic — but it is idempotent, so if one
--     statement fails, fix it and run the whole file again.
-- ---------------------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n from public.leagues where id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid;
  if n <> 1 then
    raise exception 'No league with id % — check the id at the top of this script.', '7f5a9813-43fa-4c4e-a068-12bed7129fe2';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1. Entrants (33) — "Team Name (Person Name)" split into the two columns.
-- ---------------------------------------------------------------------------
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.entrants (league_id, full_name, team_name)
select l.id, v.full_name, v.team_name
from league l
cross join (values
  ('Chris Adkins',      'Jam Lilo United'),  -- tab 1
  ('AI',                'Correct Score Cartel'),  -- tab 2
  ('Matt Adkins',       'Forever Blowing Predictions'),  -- tab 3
  ('Paul Kinsella',     'Kins Killers'),  -- tab 4
  ('George Oldroyd',    'For Farkes Sake'),  -- tab 5
  ('Bob Merchant',      'Waitrose FC'),  -- tab 6
  ('Mark Wilkinson',    'Don''t Look Back Elanga'),  -- tab 7
  ('Harry Adkins',      'Reece''s Pieces'),  -- tab 8
  ('Kay Adkins',        'Hammered Nan'),  -- tab 9
  ('Kevin Banks',       'CAOS 6'),  -- tab 10
  ('William Banks',     'ACB'),  -- tab 11
  ('Jason Wilks',       'Wilksy''s Warriors'),  -- tab 12
  ('Ben Watson',        'XR219'),  -- tab 13
  ('Penny Watson',      'PeaNUFC'),  -- tab 14
  ('Raymond Watson',    'Darth''s Raiders'),  -- tab 15
  ('Ria Merchant',      'Taking The Mikel'),  -- tab 16
  ('Liam Merchant',     'Banan Anan Doo Doo Doo Doo Doo'),  -- tab 17
  ('Ian Cantwell',      'Mind The Gap'),  -- tab 18
  ('Gary Morgan',       'Some Jaouen And Some You Lose'),  -- tab 20
  ('Macauley Duke',     'The Dukes'),  -- tab 21
  ('Shabbir Boksh',     'Boksh-to-Boksh'),  -- tab 22
  ('Nancy Sharma',      'Nancy Drew Your Predictions'),  -- tab 23
  ('Mirko Kola',        'The Eagles Pitt Stop'),  -- tab 24
  ('Tony Styles',       'TFC'),  -- tab 25
  ('Jonathan Snaith',   'Weah Better Than This'),  -- tab 26
  ('Matthew Noble',     'Victor Moses Lawn'),  -- tab 27
  ('Oliver Banks',      'Schar Wars'),  -- tab 28
  ('Oliver Pocock',     'SSC Napollie'),  -- tab 29
  ('Simon McNicholas',  'Romans Rascals'),  -- tab 30
  ('Matthew Newton',    'Geordie Goal Getters'),  -- tab 31
  ('James Seabury',     'Tricky Trees'),  -- tab 32
  ('Aashique Ahmed',    'Blasterz'),  -- tab 33
  ('Jordan Collington', 'Colly''s Mags')  -- tab 34
) as v(full_name, team_name)
-- Matched on full_name ALONE, deliberately. Matching on team_name too means
-- an entrant you had already added with a different team spelling (a trailing
-- space, a missing apostrophe, a blank) does not match, and this inserts a
-- SECOND row for the same person. The predictions below then attach to one
-- copy while the table shows the other, empty, at the bottom of the league.
where not exists (
  select 1 from public.entrants e
  where e.league_id = l.id
    and lower(btrim(e.full_name)) = lower(btrim(v.full_name))
);

-- ---------------------------------------------------------------------------
-- 2. Fixtures (47) — gameweeks derived from the date clusters on the
--    "Matches and Actual Results" tab:
--      GW1 = games 1-7  (21st Aug – 22nd Aug)
--      GW2 = games 8-15  (28th Aug – 29th Aug)
--      GW3 = games 16-23  (04th Sep – 05th Sep)
--      GW4 = games 24-31  (11th Sep – 12th Sep)
--      GW5 = games 32-40  (18th Sep – 19th Sep)
--      GW6 = games 41-47  (25th Sep – 26th Sep)
--    kickoff stays null: the sheet's dates are display text with no year or time.
-- ---------------------------------------------------------------------------
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.fixtures (league_id, gameweek, home_team, away_team, home_score, away_score)
select l.id, v.gameweek, v.home_team, v.away_team, v.home_score, v.away_score
from league l
cross join (values
  (1, 'Arsenal',              'Coventry City',        3, 0),  -- game 1
  (1, 'Birmingham City',      'Bristol City',         2, 2),  -- game 2
  (1, 'Hull City',            'Manchester United',    2, 0),  -- game 3
  (1, 'Everton',              'Crystal Palace',       2, 0),  -- game 4
  (1, 'Ipswich Town',         'Sunderland',           2, 1),  -- game 5
  (1, 'Nottingham Forest',    'Leeds United',         0, 1),  -- game 6
  (1, 'Brentford',            'Tottenham Hotspur',    3, 0),  -- game 7
  (2, 'Crystal Palace',       'Manchester City',      1, 4),  -- game 8
  (2, 'Wrexham',              'Birmingham City',      1, 2),  -- game 9
  (2, 'Middlesbrough',        'West Bromwich Albion', 3, 1),  -- game 10
  (2, 'Liverpool',            'Nottingham Forest',    2, 2),  -- game 11
  (2, 'AFC Bournemouth',      'Everton',              1, 1),  -- game 12
  (2, 'Coventry City',        'Hull City',            0, 1),  -- game 13
  (2, 'Tottenham Hotspur',    'Newcastle United',     0, 2),  -- game 14
  (2, 'Watford',              'West Ham United',      1, 1),  -- game 15
  (3, 'Ipswich Town',         'Liverpool',            0, 2),  -- game 16
  (3, 'Newcastle United',     'AFC Bournemouth',      2, 2),  -- game 17
  (3, 'Brentford',            'Sunderland',           1, 1),  -- game 18
  (3, 'Brighton Hove Albion', 'Leeds United',         1, 1),  -- game 19
  (3, 'Fulham',               'Crystal Palace',       2, 3),  -- game 20
  (3, 'Manchester City',      'Coventry City',        1, 0),  -- game 21
  (3, 'Nottingham Forest',    'Tottenham Hotspur',    0, 0),  -- game 22
  (3, 'Hull City',            'Aston Villa',          0, 0),  -- game 23
  (4, 'West Ham United',      'Wrexham',              null, null),  -- game 24
  (4, 'Aston Villa',          'Nottingham Forest',    null, null),  -- game 25
  (4, 'AFC Bournemouth',      'Brentford',            null, null),  -- game 26
  (4, 'Chelsea',              'Hull City',            null, null),  -- game 27
  (4, 'Crystal Palace',       'Ipswich Town',         null, null),  -- game 28
  (4, 'Liverpool',            'Fulham',               null, null),  -- game 29
  (4, 'Tottenham Hotspur',    'Everton',              null, null),  -- game 30
  (4, 'Sunderland',           'Arsenal',              null, null),  -- game 31
  (5, 'Brentford',            'Chelsea',              null, null),  -- game 32
  (5, 'Bristol City',         'Watford',              null, null),  -- game 33
  (5, 'Tottenham Hotspur',    'Aston Villa',          null, null),  -- game 34
  (5, 'Brighton Hove Albion', 'Arsenal',              null, null),  -- game 35
  (5, 'Everton',              'Ipswich Town',         null, null),  -- game 36
  (5, 'Millwall',             'West Ham United',      null, null),  -- game 37
  (5, 'Wrexham',              'Southampton',          null, null),  -- game 38
  (5, 'Newcastle United',     'Hull City',            null, null),  -- game 39
  (5, 'Nottingham Forest',    'Coventry City',        null, null),  -- game 40
  (6, 'Georgia',              'Northern Ireland',     null, null),  -- game 41
  (6, 'Italy',                'Belgium',              null, null),  -- game 42
  (6, 'Turkey',               'France',               null, null),  -- game 43
  (6, 'Slovenia',             'Scotland',             null, null),  -- game 44
  (6, 'San Marino',           'Finland',              null, null),  -- game 45
  (6, 'Czech Republic',       'Croatia',              null, null),  -- game 46
  (6, 'England',              'Spain',                null, null)  -- game 47
) as v(gameweek, home_team, away_team, home_score, away_score)
where not exists (
  select 1 from public.fixtures f
  where f.league_id = l.id
    and f.gameweek  = v.gameweek
    and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
    and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
);

-- Re-running also repairs results on fixtures that already existed. Only games
-- the sheet has a score for are listed, so nothing gets nulled back out.
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
update public.fixtures f
set home_score = v.home_score,
    away_score = v.away_score
from league l, (values
  (1, 'Arsenal',              'Coventry City',        3, 0),  -- game 1
  (1, 'Birmingham City',      'Bristol City',         2, 2),  -- game 2
  (1, 'Hull City',            'Manchester United',    2, 0),  -- game 3
  (1, 'Everton',              'Crystal Palace',       2, 0),  -- game 4
  (1, 'Ipswich Town',         'Sunderland',           2, 1),  -- game 5
  (1, 'Nottingham Forest',    'Leeds United',         0, 1),  -- game 6
  (1, 'Brentford',            'Tottenham Hotspur',    3, 0),  -- game 7
  (2, 'Crystal Palace',       'Manchester City',      1, 4),  -- game 8
  (2, 'Wrexham',              'Birmingham City',      1, 2),  -- game 9
  (2, 'Middlesbrough',        'West Bromwich Albion', 3, 1),  -- game 10
  (2, 'Liverpool',            'Nottingham Forest',    2, 2),  -- game 11
  (2, 'AFC Bournemouth',      'Everton',              1, 1),  -- game 12
  (2, 'Coventry City',        'Hull City',            0, 1),  -- game 13
  (2, 'Tottenham Hotspur',    'Newcastle United',     0, 2),  -- game 14
  (2, 'Watford',              'West Ham United',      1, 1),  -- game 15
  (3, 'Ipswich Town',         'Liverpool',            0, 2),  -- game 16
  (3, 'Newcastle United',     'AFC Bournemouth',      2, 2),  -- game 17
  (3, 'Brentford',            'Sunderland',           1, 1),  -- game 18
  (3, 'Brighton Hove Albion', 'Leeds United',         1, 1),  -- game 19
  (3, 'Fulham',               'Crystal Palace',       2, 3),  -- game 20
  (3, 'Manchester City',      'Coventry City',        1, 0),  -- game 21
  (3, 'Nottingham Forest',    'Tottenham Hotspur',    0, 0),  -- game 22
  (3, 'Hull City',            'Aston Villa',          0, 0)  -- game 23
) as v(gameweek, home_team, away_team, home_score, away_score)
where f.league_id = l.id
  and f.gameweek  = v.gameweek
  and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
  and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
  and (f.home_score is distinct from v.home_score
    or f.away_score is distinct from v.away_score);

-- ---------------------------------------------------------------------------
-- 3. Predictions (1192). Entrant and fixture are joined by name, so this
--    works whatever uuids the two inserts above produced. unique (fixture_id,
--    entrant_id) is the app's own conflict target (js/lib/store.js upsertPredictions).
--    is_bonus = the sheet's "Gamble" flag (column O), one per gameweek per entrant.
--
--    ONE STATEMENT PER ENTRANT, not one giant insert. A single insert carrying
--    all 1192 rows is ~120 KB, and a statement that size can be truncated
--    before it reaches the server — which silently leaves the entrants at the
--    end of the file with no predictions at all. Small statements also mean a
--    failure names the person it stopped on.
-- ---------------------------------------------------------------------------
-- tab 1: Jam Lilo United (Chris Adkins) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Chris Adkins',      1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Chris Adkins',      1, 'Birmingham City',      'Bristol City',         1, 1, false),  -- game 2
  ('Chris Adkins',      1, 'Hull City',            'Manchester United',    0, 2, false),  -- game 3
  ('Chris Adkins',      1, 'Everton',              'Crystal Palace',       1, 0, false),  -- game 4
  ('Chris Adkins',      1, 'Ipswich Town',         'Sunderland',           1, 1, false),  -- game 5
  ('Chris Adkins',      1, 'Nottingham Forest',    'Leeds United',         1, 1, false),  -- game 6
  ('Chris Adkins',      1, 'Brentford',            'Tottenham Hotspur',    1, 2, false),  -- game 7
  ('Chris Adkins',      2, 'Crystal Palace',       'Manchester City',      0, 2, true ),  -- game 8
  ('Chris Adkins',      2, 'Wrexham',              'Birmingham City',      1, 1, false),  -- game 9
  ('Chris Adkins',      2, 'Middlesbrough',        'West Bromwich Albion', 1, 0, false),  -- game 10
  ('Chris Adkins',      2, 'Liverpool',            'Nottingham Forest',    2, 0, false),  -- game 11
  ('Chris Adkins',      2, 'AFC Bournemouth',      'Everton',              2, 2, false),  -- game 12
  ('Chris Adkins',      2, 'Coventry City',        'Hull City',            1, 0, false),  -- game 13
  ('Chris Adkins',      2, 'Tottenham Hotspur',    'Newcastle United',     1, 1, false),  -- game 14
  ('Chris Adkins',      2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Chris Adkins',      3, 'Ipswich Town',         'Liverpool',            1, 2, false),  -- game 16
  ('Chris Adkins',      3, 'Newcastle United',     'AFC Bournemouth',      1, 1, false),  -- game 17
  ('Chris Adkins',      3, 'Brentford',            'Sunderland',           2, 1, false),  -- game 18
  ('Chris Adkins',      3, 'Brighton Hove Albion', 'Leeds United',         1, 0, false),  -- game 19
  ('Chris Adkins',      3, 'Fulham',               'Crystal Palace',       1, 0, false),  -- game 20
  ('Chris Adkins',      3, 'Manchester City',      'Coventry City',        2, 0, true ),  -- game 21
  ('Chris Adkins',      3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 1, false),  -- game 22
  ('Chris Adkins',      3, 'Hull City',            'Aston Villa',          1, 1, false),  -- game 23
  ('Chris Adkins',      4, 'West Ham United',      'Wrexham',              2, 1, true ),  -- game 24
  ('Chris Adkins',      4, 'Aston Villa',          'Nottingham Forest',    1, 1, false),  -- game 25
  ('Chris Adkins',      4, 'AFC Bournemouth',      'Brentford',            2, 2, false),  -- game 26
  ('Chris Adkins',      4, 'Chelsea',              'Hull City',            2, 1, false),  -- game 27
  ('Chris Adkins',      4, 'Crystal Palace',       'Ipswich Town',         1, 1, false),  -- game 28
  ('Chris Adkins',      4, 'Liverpool',            'Fulham',               2, 0, false),  -- game 29
  ('Chris Adkins',      4, 'Tottenham Hotspur',    'Everton',              1, 1, false),  -- game 30
  ('Chris Adkins',      4, 'Sunderland',           'Arsenal',              0, 2, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 2: Correct Score Cartel (AI) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('AI',                1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('AI',                1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('AI',                1, 'Hull City',            'Manchester United',    1, 2, false),  -- game 3
  ('AI',                1, 'Everton',              'Crystal Palace',       2, 1, false),  -- game 4
  ('AI',                1, 'Ipswich Town',         'Sunderland',           2, 1, false),  -- game 5
  ('AI',                1, 'Nottingham Forest',    'Leeds United',         1, 1, false),  -- game 6
  ('AI',                1, 'Brentford',            'Tottenham Hotspur',    2, 1, false),  -- game 7
  ('AI',                2, 'Crystal Palace',       'Manchester City',      1, 3, false),  -- game 8
  ('AI',                2, 'Wrexham',              'Birmingham City',      1, 1, false),  -- game 9
  ('AI',                2, 'Middlesbrough',        'West Bromwich Albion', 2, 1, false),  -- game 10
  ('AI',                2, 'Liverpool',            'Nottingham Forest',    3, 0, true ),  -- game 11
  ('AI',                2, 'AFC Bournemouth',      'Everton',              2, 1, false),  -- game 12
  ('AI',                2, 'Coventry City',        'Hull City',            2, 0, false),  -- game 13
  ('AI',                2, 'Tottenham Hotspur',    'Newcastle United',     2, 2, false),  -- game 14
  ('AI',                2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('AI',                3, 'Ipswich Town',         'Liverpool',            1, 3, false),  -- game 16
  ('AI',                3, 'Newcastle United',     'AFC Bournemouth',      2, 1, true ),  -- game 17
  ('AI',                3, 'Brentford',            'Sunderland',           2, 0, false),  -- game 18
  ('AI',                3, 'Brighton Hove Albion', 'Leeds United',         2, 1, false),  -- game 19
  ('AI',                3, 'Fulham',               'Crystal Palace',       1, 1, false),  -- game 20
  ('AI',                3, 'Manchester City',      'Coventry City',        3, 0, false),  -- game 21
  ('AI',                3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 2, false),  -- game 22
  ('AI',                3, 'Hull City',            'Aston Villa',          0, 2, false),  -- game 23
  ('AI',                4, 'West Ham United',      'Wrexham',              2, 0, false),  -- game 24
  ('AI',                4, 'Aston Villa',          'Nottingham Forest',    2, 1, false),  -- game 25
  ('AI',                4, 'AFC Bournemouth',      'Brentford',            2, 1, false),  -- game 26
  ('AI',                4, 'Chelsea',              'Hull City',            3, 0, true ),  -- game 27
  ('AI',                4, 'Crystal Palace',       'Ipswich Town',         2, 0, false),  -- game 28
  ('AI',                4, 'Liverpool',            'Fulham',               3, 1, false),  -- game 29
  ('AI',                4, 'Tottenham Hotspur',    'Everton',              2, 1, false),  -- game 30
  ('AI',                4, 'Sunderland',           'Arsenal',              0, 2, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 3: Forever Blowing Predictions (Matt Adkins) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Matt Adkins',       1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Matt Adkins',       1, 'Birmingham City',      'Bristol City',         1, 1, false),  -- game 2
  ('Matt Adkins',       1, 'Hull City',            'Manchester United',    1, 2, false),  -- game 3
  ('Matt Adkins',       1, 'Everton',              'Crystal Palace',       1, 0, false),  -- game 4
  ('Matt Adkins',       1, 'Ipswich Town',         'Sunderland',           0, 1, false),  -- game 5
  ('Matt Adkins',       1, 'Nottingham Forest',    'Leeds United',         2, 1, false),  -- game 6
  ('Matt Adkins',       1, 'Brentford',            'Tottenham Hotspur',    1, 1, false),  -- game 7
  ('Matt Adkins',       2, 'Crystal Palace',       'Manchester City',      0, 3, false),  -- game 8
  ('Matt Adkins',       2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Matt Adkins',       2, 'Middlesbrough',        'West Bromwich Albion', 0, 2, true ),  -- game 10
  ('Matt Adkins',       2, 'Liverpool',            'Nottingham Forest',    2, 1, false),  -- game 11
  ('Matt Adkins',       2, 'AFC Bournemouth',      'Everton',              0, 1, false),  -- game 12
  ('Matt Adkins',       2, 'Coventry City',        'Hull City',            0, 1, false),  -- game 13
  ('Matt Adkins',       2, 'Tottenham Hotspur',    'Newcastle United',     1, 2, false),  -- game 14
  ('Matt Adkins',       2, 'Watford',              'West Ham United',      2, 2, false),  -- game 15
  ('Matt Adkins',       3, 'Ipswich Town',         'Liverpool',            1, 2, false),  -- game 16
  ('Matt Adkins',       3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('Matt Adkins',       3, 'Brentford',            'Sunderland',           1, 0, false),  -- game 18
  ('Matt Adkins',       3, 'Brighton Hove Albion', 'Leeds United',         1, 1, false),  -- game 19
  ('Matt Adkins',       3, 'Fulham',               'Crystal Palace',       2, 0, false),  -- game 20
  ('Matt Adkins',       3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('Matt Adkins',       3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 0, false),  -- game 22
  ('Matt Adkins',       3, 'Hull City',            'Aston Villa',          2, 1, false),  -- game 23
  ('Matt Adkins',       4, 'West Ham United',      'Wrexham',              1, 0, false),  -- game 24
  ('Matt Adkins',       4, 'Aston Villa',          'Nottingham Forest',    1, 1, false),  -- game 25
  ('Matt Adkins',       4, 'AFC Bournemouth',      'Brentford',            0, 2, false),  -- game 26
  ('Matt Adkins',       4, 'Chelsea',              'Hull City',            2, 1, false),  -- game 27
  ('Matt Adkins',       4, 'Crystal Palace',       'Ipswich Town',         1, 1, false),  -- game 28
  ('Matt Adkins',       4, 'Liverpool',            'Fulham',               2, 0, true ),  -- game 29
  ('Matt Adkins',       4, 'Tottenham Hotspur',    'Everton',              1, 2, false),  -- game 30
  ('Matt Adkins',       4, 'Sunderland',           'Arsenal',              1, 3, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 4: Kins Killers (Paul Kinsella) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Paul Kinsella',     1, 'Arsenal',              'Coventry City',        2, 1, false),  -- game 1
  ('Paul Kinsella',     1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Paul Kinsella',     1, 'Hull City',            'Manchester United',    1, 3, false),  -- game 3
  ('Paul Kinsella',     1, 'Everton',              'Crystal Palace',       2, 0, false),  -- game 4
  ('Paul Kinsella',     1, 'Ipswich Town',         'Sunderland',           2, 1, true ),  -- game 5
  ('Paul Kinsella',     1, 'Nottingham Forest',    'Leeds United',         3, 1, false),  -- game 6
  ('Paul Kinsella',     1, 'Brentford',            'Tottenham Hotspur',    2, 1, false),  -- game 7
  ('Paul Kinsella',     2, 'Crystal Palace',       'Manchester City',      1, 3, false),  -- game 8
  ('Paul Kinsella',     2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Paul Kinsella',     2, 'Middlesbrough',        'West Bromwich Albion', 2, 0, false),  -- game 10
  ('Paul Kinsella',     2, 'Liverpool',            'Nottingham Forest',    3, 0, true ),  -- game 11
  ('Paul Kinsella',     2, 'AFC Bournemouth',      'Everton',              2, 1, false),  -- game 12
  ('Paul Kinsella',     2, 'Coventry City',        'Hull City',            2, 0, false),  -- game 13
  ('Paul Kinsella',     2, 'Tottenham Hotspur',    'Newcastle United',     3, 1, false),  -- game 14
  ('Paul Kinsella',     2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Paul Kinsella',     3, 'Ipswich Town',         'Liverpool',            1, 3, false),  -- game 16
  ('Paul Kinsella',     3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('Paul Kinsella',     3, 'Brentford',            'Sunderland',           2, 0, false),  -- game 18
  ('Paul Kinsella',     3, 'Brighton Hove Albion', 'Leeds United',         1, 0, false),  -- game 19
  ('Paul Kinsella',     3, 'Fulham',               'Crystal Palace',       2, 0, false),  -- game 20
  ('Paul Kinsella',     3, 'Manchester City',      'Coventry City',        4, 0, true ),  -- game 21
  ('Paul Kinsella',     3, 'Nottingham Forest',    'Tottenham Hotspur',    3, 1, false),  -- game 22
  ('Paul Kinsella',     3, 'Hull City',            'Aston Villa',          0, 2, false),  -- game 23
  ('Paul Kinsella',     4, 'West Ham United',      'Wrexham',              2, 1, false),  -- game 24
  ('Paul Kinsella',     4, 'Aston Villa',          'Nottingham Forest',    2, 1, false),  -- game 25
  ('Paul Kinsella',     4, 'AFC Bournemouth',      'Brentford',            3, 2, false),  -- game 26
  ('Paul Kinsella',     4, 'Chelsea',              'Hull City',            2, 0, false),  -- game 27
  ('Paul Kinsella',     4, 'Crystal Palace',       'Ipswich Town',         2, 0, false),  -- game 28
  ('Paul Kinsella',     4, 'Liverpool',            'Fulham',               3, 0, true ),  -- game 29
  ('Paul Kinsella',     4, 'Tottenham Hotspur',    'Everton',              1, 2, false),  -- game 30
  ('Paul Kinsella',     4, 'Sunderland',           'Arsenal',              1, 3, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 5: For Farkes Sake (George Oldroyd) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('George Oldroyd',    1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('George Oldroyd',    1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('George Oldroyd',    1, 'Hull City',            'Manchester United',    0, 2, false),  -- game 3
  ('George Oldroyd',    1, 'Everton',              'Crystal Palace',       1, 0, false),  -- game 4
  ('George Oldroyd',    1, 'Ipswich Town',         'Sunderland',           1, 1, false),  -- game 5
  ('George Oldroyd',    1, 'Nottingham Forest',    'Leeds United',         1, 2, false),  -- game 6
  ('George Oldroyd',    1, 'Brentford',            'Tottenham Hotspur',    2, 2, false),  -- game 7
  ('George Oldroyd',    2, 'Crystal Palace',       'Manchester City',      0, 2, false),  -- game 8
  ('George Oldroyd',    2, 'Wrexham',              'Birmingham City',      1, 0, false),  -- game 9
  ('George Oldroyd',    2, 'Middlesbrough',        'West Bromwich Albion', 1, 2, false),  -- game 10
  ('George Oldroyd',    2, 'Liverpool',            'Nottingham Forest',    2, 0, true ),  -- game 11
  ('George Oldroyd',    2, 'AFC Bournemouth',      'Everton',              0, 2, false),  -- game 12
  ('George Oldroyd',    2, 'Coventry City',        'Hull City',            1, 1, false),  -- game 13
  ('George Oldroyd',    2, 'Tottenham Hotspur',    'Newcastle United',     1, 1, false),  -- game 14
  ('George Oldroyd',    2, 'Watford',              'West Ham United',      1, 0, false),  -- game 15
  ('George Oldroyd',    3, 'Ipswich Town',         'Liverpool',            1, 2, false),  -- game 16
  ('George Oldroyd',    3, 'Newcastle United',     'AFC Bournemouth',      1, 1, false),  -- game 17
  ('George Oldroyd',    3, 'Brentford',            'Sunderland',           2, 0, false),  -- game 18
  ('George Oldroyd',    3, 'Brighton Hove Albion', 'Leeds United',         1, 2, false),  -- game 19
  ('George Oldroyd',    3, 'Fulham',               'Crystal Palace',       1, 0, false),  -- game 20
  ('George Oldroyd',    3, 'Manchester City',      'Coventry City',        2, 0, true ),  -- game 21
  ('George Oldroyd',    3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 1, false),  -- game 22
  ('George Oldroyd',    3, 'Hull City',            'Aston Villa',          1, 0, false),  -- game 23
  ('George Oldroyd',    4, 'West Ham United',      'Wrexham',              2, 0, false),  -- game 24
  ('George Oldroyd',    4, 'Aston Villa',          'Nottingham Forest',    1, 0, false),  -- game 25
  ('George Oldroyd',    4, 'AFC Bournemouth',      'Brentford',            2, 2, false),  -- game 26
  ('George Oldroyd',    4, 'Chelsea',              'Hull City',            2, 1, true ),  -- game 27
  ('George Oldroyd',    4, 'Crystal Palace',       'Ipswich Town',         1, 0, false),  -- game 28
  ('George Oldroyd',    4, 'Liverpool',            'Fulham',               2, 0, false),  -- game 29
  ('George Oldroyd',    4, 'Tottenham Hotspur',    'Everton',              1, 2, false),  -- game 30
  ('George Oldroyd',    4, 'Sunderland',           'Arsenal',              1, 3, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 6: Waitrose FC (Bob Merchant) (47)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Bob Merchant',      1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Bob Merchant',      1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Bob Merchant',      1, 'Hull City',            'Manchester United',    1, 1, false),  -- game 3
  ('Bob Merchant',      1, 'Everton',              'Crystal Palace',       2, 1, false),  -- game 4
  ('Bob Merchant',      1, 'Ipswich Town',         'Sunderland',           1, 2, false),  -- game 5
  ('Bob Merchant',      1, 'Nottingham Forest',    'Leeds United',         1, 1, false),  -- game 6
  ('Bob Merchant',      1, 'Brentford',            'Tottenham Hotspur',    2, 1, false),  -- game 7
  ('Bob Merchant',      2, 'Crystal Palace',       'Manchester City',      1, 2, false),  -- game 8
  ('Bob Merchant',      2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Bob Merchant',      2, 'Middlesbrough',        'West Bromwich Albion', 1, 1, false),  -- game 10
  ('Bob Merchant',      2, 'Liverpool',            'Nottingham Forest',    2, 1, false),  -- game 11
  ('Bob Merchant',      2, 'AFC Bournemouth',      'Everton',              1, 1, false),  -- game 12
  ('Bob Merchant',      2, 'Coventry City',        'Hull City',            2, 0, false),  -- game 13
  ('Bob Merchant',      2, 'Tottenham Hotspur',    'Newcastle United',     2, 0, false),  -- game 14
  ('Bob Merchant',      2, 'Watford',              'West Ham United',      1, 2, true ),  -- game 15
  ('Bob Merchant',      3, 'Ipswich Town',         'Liverpool',            1, 1, false),  -- game 16
  ('Bob Merchant',      3, 'Newcastle United',     'AFC Bournemouth',      1, 2, false),  -- game 17
  ('Bob Merchant',      3, 'Brentford',            'Sunderland',           1, 1, false),  -- game 18
  ('Bob Merchant',      3, 'Brighton Hove Albion', 'Leeds United',         2, 0, false),  -- game 19
  ('Bob Merchant',      3, 'Fulham',               'Crystal Palace',       1, 1, false),  -- game 20
  ('Bob Merchant',      3, 'Manchester City',      'Coventry City',        2, 0, false),  -- game 21
  ('Bob Merchant',      3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 2, true ),  -- game 22
  ('Bob Merchant',      3, 'Hull City',            'Aston Villa',          1, 2, false),  -- game 23
  ('Bob Merchant',      4, 'West Ham United',      'Wrexham',              2, 0, false),  -- game 24
  ('Bob Merchant',      4, 'Aston Villa',          'Nottingham Forest',    1, 1, false),  -- game 25
  ('Bob Merchant',      4, 'AFC Bournemouth',      'Brentford',            2, 0, false),  -- game 26
  ('Bob Merchant',      4, 'Chelsea',              'Hull City',            3, 0, false),  -- game 27
  ('Bob Merchant',      4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('Bob Merchant',      4, 'Liverpool',            'Fulham',               3, 1, false),  -- game 29
  ('Bob Merchant',      4, 'Tottenham Hotspur',    'Everton',              1, 1, false),  -- game 30
  ('Bob Merchant',      4, 'Sunderland',           'Arsenal',              0, 2, true ),  -- game 31
  ('Bob Merchant',      5, 'Brentford',            'Chelsea',              1, 2, false),  -- game 32
  ('Bob Merchant',      5, 'Bristol City',         'Watford',              2, 0, false),  -- game 33
  ('Bob Merchant',      5, 'Tottenham Hotspur',    'Aston Villa',          1, 1, false),  -- game 34
  ('Bob Merchant',      5, 'Brighton Hove Albion', 'Arsenal',              1, 1, false),  -- game 35
  ('Bob Merchant',      5, 'Everton',              'Ipswich Town',         2, 0, false),  -- game 36
  ('Bob Merchant',      5, 'Millwall',             'West Ham United',      1, 3, false),  -- game 37
  ('Bob Merchant',      5, 'Wrexham',              'Southampton',          2, 1, false),  -- game 38
  ('Bob Merchant',      5, 'Newcastle United',     'Hull City',            2, 1, false),  -- game 39
  ('Bob Merchant',      5, 'Nottingham Forest',    'Coventry City',        1, 1, false),  -- game 40
  ('Bob Merchant',      6, 'Georgia',              'Northern Ireland',     1, 1, false),  -- game 41
  ('Bob Merchant',      6, 'Italy',                'Belgium',              2, 1, false),  -- game 42
  ('Bob Merchant',      6, 'Turkey',               'France',               1, 3, false),  -- game 43
  ('Bob Merchant',      6, 'Slovenia',             'Scotland',             1, 0, false),  -- game 44
  ('Bob Merchant',      6, 'San Marino',           'Finland',              0, 1, false),  -- game 45
  ('Bob Merchant',      6, 'Czech Republic',       'Croatia',              1, 1, false),  -- game 46
  ('Bob Merchant',      6, 'England',              'Spain',                2, 1, false)  -- game 47
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 7: Don't Look Back Elanga (Mark Wilkinson) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Mark Wilkinson',    1, 'Arsenal',              'Coventry City',        2, 0, false),  -- game 1
  ('Mark Wilkinson',    1, 'Birmingham City',      'Bristol City',         1, 1, false),  -- game 2
  ('Mark Wilkinson',    1, 'Hull City',            'Manchester United',    0, 2, false),  -- game 3
  ('Mark Wilkinson',    1, 'Everton',              'Crystal Palace',       2, 1, true ),  -- game 4
  ('Mark Wilkinson',    1, 'Ipswich Town',         'Sunderland',           1, 0, false),  -- game 5
  ('Mark Wilkinson',    1, 'Nottingham Forest',    'Leeds United',         2, 2, false),  -- game 6
  ('Mark Wilkinson',    1, 'Brentford',            'Tottenham Hotspur',    0, 1, false),  -- game 7
  ('Mark Wilkinson',    2, 'Crystal Palace',       'Manchester City',      0, 2, false),  -- game 8
  ('Mark Wilkinson',    2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Mark Wilkinson',    2, 'Middlesbrough',        'West Bromwich Albion', 3, 1, false),  -- game 10
  ('Mark Wilkinson',    2, 'Liverpool',            'Nottingham Forest',    2, 0, true ),  -- game 11
  ('Mark Wilkinson',    2, 'AFC Bournemouth',      'Everton',              1, 1, false),  -- game 12
  ('Mark Wilkinson',    2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Mark Wilkinson',    2, 'Tottenham Hotspur',    'Newcastle United',     0, 1, false),  -- game 14
  ('Mark Wilkinson',    2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Mark Wilkinson',    3, 'Ipswich Town',         'Liverpool',            1, 3, false),  -- game 16
  ('Mark Wilkinson',    3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('Mark Wilkinson',    3, 'Brentford',            'Sunderland',           3, 1, false),  -- game 18
  ('Mark Wilkinson',    3, 'Brighton Hove Albion', 'Leeds United',         3, 1, false),  -- game 19
  ('Mark Wilkinson',    3, 'Fulham',               'Crystal Palace',       2, 1, false),  -- game 20
  ('Mark Wilkinson',    3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('Mark Wilkinson',    3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 1, false),  -- game 22
  ('Mark Wilkinson',    3, 'Hull City',            'Aston Villa',          1, 2, false),  -- game 23
  ('Mark Wilkinson',    4, 'West Ham United',      'Wrexham',              2, 1, false),  -- game 24
  ('Mark Wilkinson',    4, 'Aston Villa',          'Nottingham Forest',    1, 0, false),  -- game 25
  ('Mark Wilkinson',    4, 'AFC Bournemouth',      'Brentford',            3, 2, false),  -- game 26
  ('Mark Wilkinson',    4, 'Chelsea',              'Hull City',            3, 0, false),  -- game 27
  ('Mark Wilkinson',    4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('Mark Wilkinson',    4, 'Liverpool',            'Fulham',               2, 0, true ),  -- game 29
  ('Mark Wilkinson',    4, 'Tottenham Hotspur',    'Everton',              1, 1, false),  -- game 30
  ('Mark Wilkinson',    4, 'Sunderland',           'Arsenal',              0, 2, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 8: Reece's Pieces (Harry Adkins) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Harry Adkins',      1, 'Arsenal',              'Coventry City',        2, 0, true ),  -- game 1
  ('Harry Adkins',      1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Harry Adkins',      1, 'Hull City',            'Manchester United',    1, 2, false),  -- game 3
  ('Harry Adkins',      1, 'Everton',              'Crystal Palace',       2, 1, false),  -- game 4
  ('Harry Adkins',      1, 'Ipswich Town',         'Sunderland',           1, 2, false),  -- game 5
  ('Harry Adkins',      1, 'Nottingham Forest',    'Leeds United',         1, 1, false),  -- game 6
  ('Harry Adkins',      1, 'Brentford',            'Tottenham Hotspur',    1, 2, false),  -- game 7
  ('Harry Adkins',      2, 'Crystal Palace',       'Manchester City',      0, 2, true ),  -- game 8
  ('Harry Adkins',      2, 'Wrexham',              'Birmingham City',      1, 0, false),  -- game 9
  ('Harry Adkins',      2, 'Middlesbrough',        'West Bromwich Albion', 2, 2, false),  -- game 10
  ('Harry Adkins',      2, 'Liverpool',            'Nottingham Forest',    2, 1, false),  -- game 11
  ('Harry Adkins',      2, 'AFC Bournemouth',      'Everton',              2, 1, false),  -- game 12
  ('Harry Adkins',      2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Harry Adkins',      2, 'Tottenham Hotspur',    'Newcastle United',     1, 1, false),  -- game 14
  ('Harry Adkins',      2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Harry Adkins',      3, 'Ipswich Town',         'Liverpool',            0, 2, false),  -- game 16
  ('Harry Adkins',      3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('Harry Adkins',      3, 'Brentford',            'Sunderland',           2, 1, false),  -- game 18
  ('Harry Adkins',      3, 'Brighton Hove Albion', 'Leeds United',         2, 1, false),  -- game 19
  ('Harry Adkins',      3, 'Fulham',               'Crystal Palace',       1, 1, false),  -- game 20
  ('Harry Adkins',      3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('Harry Adkins',      3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 2, false),  -- game 22
  ('Harry Adkins',      3, 'Hull City',            'Aston Villa',          0, 1, false),  -- game 23
  ('Harry Adkins',      4, 'West Ham United',      'Wrexham',              3, 1, false),  -- game 24
  ('Harry Adkins',      4, 'Aston Villa',          'Nottingham Forest',    2, 1, false),  -- game 25
  ('Harry Adkins',      4, 'AFC Bournemouth',      'Brentford',            0, 1, false),  -- game 26
  ('Harry Adkins',      4, 'Chelsea',              'Hull City',            3, 1, false),  -- game 27
  ('Harry Adkins',      4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('Harry Adkins',      4, 'Liverpool',            'Fulham',               2, 0, true ),  -- game 29
  ('Harry Adkins',      4, 'Tottenham Hotspur',    'Everton',              1, 1, false),  -- game 30
  ('Harry Adkins',      4, 'Sunderland',           'Arsenal',              0, 2, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 9: Hammered Nan (Kay Adkins) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Kay Adkins',        1, 'Arsenal',              'Coventry City',        2, 1, true ),  -- game 1
  ('Kay Adkins',        1, 'Birmingham City',      'Bristol City',         0, 1, false),  -- game 2
  ('Kay Adkins',        1, 'Hull City',            'Manchester United',    1, 2, false),  -- game 3
  ('Kay Adkins',        1, 'Everton',              'Crystal Palace',       1, 1, false),  -- game 4
  ('Kay Adkins',        1, 'Ipswich Town',         'Sunderland',           1, 1, false),  -- game 5
  ('Kay Adkins',        1, 'Nottingham Forest',    'Leeds United',         0, 1, false),  -- game 6
  ('Kay Adkins',        1, 'Brentford',            'Tottenham Hotspur',    1, 1, false),  -- game 7
  ('Kay Adkins',        2, 'Crystal Palace',       'Manchester City',      0, 2, false),  -- game 8
  ('Kay Adkins',        2, 'Wrexham',              'Birmingham City',      1, 0, false),  -- game 9
  ('Kay Adkins',        2, 'Middlesbrough',        'West Bromwich Albion', 1, 0, false),  -- game 10
  ('Kay Adkins',        2, 'Liverpool',            'Nottingham Forest',    2, 0, true ),  -- game 11
  ('Kay Adkins',        2, 'AFC Bournemouth',      'Everton',              1, 1, false),  -- game 12
  ('Kay Adkins',        2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Kay Adkins',        2, 'Tottenham Hotspur',    'Newcastle United',     1, 1, false),  -- game 14
  ('Kay Adkins',        2, 'Watford',              'West Ham United',      1, 1, false),  -- game 15
  ('Kay Adkins',        3, 'Ipswich Town',         'Liverpool',            1, 2, false),  -- game 16
  ('Kay Adkins',        3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('Kay Adkins',        3, 'Brentford',            'Sunderland',           2, 1, false),  -- game 18
  ('Kay Adkins',        3, 'Brighton Hove Albion', 'Leeds United',         2, 0, false),  -- game 19
  ('Kay Adkins',        3, 'Fulham',               'Crystal Palace',       1, 0, false),  -- game 20
  ('Kay Adkins',        3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('Kay Adkins',        3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 0, false),  -- game 22
  ('Kay Adkins',        3, 'Hull City',            'Aston Villa',          1, 1, false),  -- game 23
  ('Kay Adkins',        4, 'West Ham United',      'Wrexham',              2, 0, true ),  -- game 24
  ('Kay Adkins',        4, 'Aston Villa',          'Nottingham Forest',    1, 0, false),  -- game 25
  ('Kay Adkins',        4, 'AFC Bournemouth',      'Brentford',            1, 1, false),  -- game 26
  ('Kay Adkins',        4, 'Chelsea',              'Hull City',            1, 0, false),  -- game 27
  ('Kay Adkins',        4, 'Crystal Palace',       'Ipswich Town',         1, 0, false),  -- game 28
  ('Kay Adkins',        4, 'Liverpool',            'Fulham',               2, 0, false),  -- game 29
  ('Kay Adkins',        4, 'Tottenham Hotspur',    'Everton',              1, 1, false),  -- game 30
  ('Kay Adkins',        4, 'Sunderland',           'Arsenal',              1, 2, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 10: CAOS 6 (Kevin Banks) (47)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Kevin Banks',       1, 'Arsenal',              'Coventry City',        4, 0, false),  -- game 1
  ('Kevin Banks',       1, 'Birmingham City',      'Bristol City',         1, 2, false),  -- game 2
  ('Kevin Banks',       1, 'Hull City',            'Manchester United',    0, 3, false),  -- game 3
  ('Kevin Banks',       1, 'Everton',              'Crystal Palace',       2, 1, false),  -- game 4
  ('Kevin Banks',       1, 'Ipswich Town',         'Sunderland',           2, 1, false),  -- game 5
  ('Kevin Banks',       1, 'Nottingham Forest',    'Leeds United',         1, 2, true ),  -- game 6
  ('Kevin Banks',       1, 'Brentford',            'Tottenham Hotspur',    3, 1, false),  -- game 7
  ('Kevin Banks',       2, 'Crystal Palace',       'Manchester City',      1, 3, false),  -- game 8
  ('Kevin Banks',       2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Kevin Banks',       2, 'Middlesbrough',        'West Bromwich Albion', 2, 0, true ),  -- game 10
  ('Kevin Banks',       2, 'Liverpool',            'Nottingham Forest',    1, 2, false),  -- game 11
  ('Kevin Banks',       2, 'AFC Bournemouth',      'Everton',              2, 1, false),  -- game 12
  ('Kevin Banks',       2, 'Coventry City',        'Hull City',            2, 0, false),  -- game 13
  ('Kevin Banks',       2, 'Tottenham Hotspur',    'Newcastle United',     1, 3, false),  -- game 14
  ('Kevin Banks',       2, 'Watford',              'West Ham United',      1, 3, false),  -- game 15
  ('Kevin Banks',       3, 'Ipswich Town',         'Liverpool',            0, 3, false),  -- game 16
  ('Kevin Banks',       3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('Kevin Banks',       3, 'Brentford',            'Sunderland',           2, 1, false),  -- game 18
  ('Kevin Banks',       3, 'Brighton Hove Albion', 'Leeds United',         1, 2, true ),  -- game 19
  ('Kevin Banks',       3, 'Fulham',               'Crystal Palace',       2, 1, false),  -- game 20
  ('Kevin Banks',       3, 'Manchester City',      'Coventry City',        4, 0, false),  -- game 21
  ('Kevin Banks',       3, 'Nottingham Forest',    'Tottenham Hotspur',    2, 1, false),  -- game 22
  ('Kevin Banks',       3, 'Hull City',            'Aston Villa',          0, 2, false),  -- game 23
  ('Kevin Banks',       4, 'West Ham United',      'Wrexham',              2, 1, false),  -- game 24
  ('Kevin Banks',       4, 'Aston Villa',          'Nottingham Forest',    2, 1, false),  -- game 25
  ('Kevin Banks',       4, 'AFC Bournemouth',      'Brentford',            2, 0, false),  -- game 26
  ('Kevin Banks',       4, 'Chelsea',              'Hull City',            3, 1, true ),  -- game 27
  ('Kevin Banks',       4, 'Crystal Palace',       'Ipswich Town',         2, 0, false),  -- game 28
  ('Kevin Banks',       4, 'Liverpool',            'Fulham',               2, 0, false),  -- game 29
  ('Kevin Banks',       4, 'Tottenham Hotspur',    'Everton',              0, 2, false),  -- game 30
  ('Kevin Banks',       4, 'Sunderland',           'Arsenal',              0, 4, false),  -- game 31
  ('Kevin Banks',       5, 'Brentford',            'Chelsea',              0, 4, false),  -- game 32
  ('Kevin Banks',       5, 'Bristol City',         'Watford',              3, 1, false),  -- game 33
  ('Kevin Banks',       5, 'Tottenham Hotspur',    'Aston Villa',          1, 2, false),  -- game 34
  ('Kevin Banks',       5, 'Brighton Hove Albion', 'Arsenal',              1, 2, false),  -- game 35
  ('Kevin Banks',       5, 'Everton',              'Ipswich Town',         2, 1, true ),  -- game 36
  ('Kevin Banks',       5, 'Millwall',             'West Ham United',      1, 3, false),  -- game 37
  ('Kevin Banks',       5, 'Wrexham',              'Southampton',          2, 1, false),  -- game 38
  ('Kevin Banks',       5, 'Newcastle United',     'Hull City',            3, 1, false),  -- game 39
  ('Kevin Banks',       5, 'Nottingham Forest',    'Coventry City',        2, 0, false),  -- game 40
  ('Kevin Banks',       6, 'Georgia',              'Northern Ireland',     1, 2, false),  -- game 41
  ('Kevin Banks',       6, 'Italy',                'Belgium',              2, 1, false),  -- game 42
  ('Kevin Banks',       6, 'Turkey',               'France',               0, 3, true ),  -- game 43
  ('Kevin Banks',       6, 'Slovenia',             'Scotland',             0, 2, false),  -- game 44
  ('Kevin Banks',       6, 'San Marino',           'Finland',              2, 1, false),  -- game 45
  ('Kevin Banks',       6, 'Czech Republic',       'Croatia',              1, 2, false),  -- game 46
  ('Kevin Banks',       6, 'England',              'Spain',                3, 0, false)  -- game 47
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 11: ACB (William Banks) (47)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('William Banks',     1, 'Arsenal',              'Coventry City',        4, 0, true ),  -- game 1
  ('William Banks',     1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('William Banks',     1, 'Hull City',            'Manchester United',    0, 2, false),  -- game 3
  ('William Banks',     1, 'Everton',              'Crystal Palace',       1, 1, false),  -- game 4
  ('William Banks',     1, 'Ipswich Town',         'Sunderland',           1, 1, false),  -- game 5
  ('William Banks',     1, 'Nottingham Forest',    'Leeds United',         1, 2, false),  -- game 6
  ('William Banks',     1, 'Brentford',            'Tottenham Hotspur',    1, 2, false),  -- game 7
  ('William Banks',     2, 'Crystal Palace',       'Manchester City',      1, 3, false),  -- game 8
  ('William Banks',     2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('William Banks',     2, 'Middlesbrough',        'West Bromwich Albion', 2, 0, false),  -- game 10
  ('William Banks',     2, 'Liverpool',            'Nottingham Forest',    3, 1, false),  -- game 11
  ('William Banks',     2, 'AFC Bournemouth',      'Everton',              2, 1, false),  -- game 12
  ('William Banks',     2, 'Coventry City',        'Hull City',            1, 1, false),  -- game 13
  ('William Banks',     2, 'Tottenham Hotspur',    'Newcastle United',     1, 1, false),  -- game 14
  ('William Banks',     2, 'Watford',              'West Ham United',      0, 2, true ),  -- game 15
  ('William Banks',     3, 'Ipswich Town',         'Liverpool',            0, 3, true ),  -- game 16
  ('William Banks',     3, 'Newcastle United',     'AFC Bournemouth',      2, 0, false),  -- game 17
  ('William Banks',     3, 'Brentford',            'Sunderland',           2, 1, false),  -- game 18
  ('William Banks',     3, 'Brighton Hove Albion', 'Leeds United',         1, 1, false),  -- game 19
  ('William Banks',     3, 'Fulham',               'Crystal Palace',       2, 2, false),  -- game 20
  ('William Banks',     3, 'Manchester City',      'Coventry City',        4, 0, false),  -- game 21
  ('William Banks',     3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 3, false),  -- game 22
  ('William Banks',     3, 'Hull City',            'Aston Villa',          2, 4, false),  -- game 23
  ('William Banks',     4, 'West Ham United',      'Wrexham',              2, 1, false),  -- game 24
  ('William Banks',     4, 'Aston Villa',          'Nottingham Forest',    2, 2, false),  -- game 25
  ('William Banks',     4, 'AFC Bournemouth',      'Brentford',            1, 1, false),  -- game 26
  ('William Banks',     4, 'Chelsea',              'Hull City',            3, 0, false),  -- game 27
  ('William Banks',     4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('William Banks',     4, 'Liverpool',            'Fulham',               2, 0, false),  -- game 29
  ('William Banks',     4, 'Tottenham Hotspur',    'Everton',              1, 2, false),  -- game 30
  ('William Banks',     4, 'Sunderland',           'Arsenal',              0, 2, true ),  -- game 31
  ('William Banks',     5, 'Brentford',            'Chelsea',              2, 4, false),  -- game 32
  ('William Banks',     5, 'Bristol City',         'Watford',              1, 2, false),  -- game 33
  ('William Banks',     5, 'Tottenham Hotspur',    'Aston Villa',          2, 2, false),  -- game 34
  ('William Banks',     5, 'Brighton Hove Albion', 'Arsenal',              2, 1, false),  -- game 35
  ('William Banks',     5, 'Everton',              'Ipswich Town',         1, 0, false),  -- game 36
  ('William Banks',     5, 'Millwall',             'West Ham United',      2, 4, false),  -- game 37
  ('William Banks',     5, 'Wrexham',              'Southampton',          3, 2, false),  -- game 38
  ('William Banks',     5, 'Newcastle United',     'Hull City',            4, 0, true ),  -- game 39
  ('William Banks',     5, 'Nottingham Forest',    'Coventry City',        2, 2, false),  -- game 40
  ('William Banks',     6, 'Georgia',              'Northern Ireland',     1, 1, false),  -- game 41
  ('William Banks',     6, 'Italy',                'Belgium',              2, 2, false),  -- game 42
  ('William Banks',     6, 'Turkey',               'France',               0, 3, false),  -- game 43
  ('William Banks',     6, 'Slovenia',             'Scotland',             0, 1, false),  -- game 44
  ('William Banks',     6, 'San Marino',           'Finland',              0, 4, false),  -- game 45
  ('William Banks',     6, 'Czech Republic',       'Croatia',              2, 1, false),  -- game 46
  ('William Banks',     6, 'England',              'Spain',                2, 1, true )  -- game 47
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 12: Wilksy's Warriors (Jason Wilks) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Jason Wilks',       1, 'Arsenal',              'Coventry City',        3, 1, true ),  -- game 1
  ('Jason Wilks',       1, 'Birmingham City',      'Bristol City',         1, 1, false),  -- game 2
  ('Jason Wilks',       1, 'Hull City',            'Manchester United',    0, 3, false),  -- game 3
  ('Jason Wilks',       1, 'Everton',              'Crystal Palace',       1, 1, false),  -- game 4
  ('Jason Wilks',       1, 'Ipswich Town',         'Sunderland',           1, 1, false),  -- game 5
  ('Jason Wilks',       1, 'Nottingham Forest',    'Leeds United',         2, 1, false),  -- game 6
  ('Jason Wilks',       1, 'Brentford',            'Tottenham Hotspur',    1, 3, false),  -- game 7
  ('Jason Wilks',       2, 'Crystal Palace',       'Manchester City',      1, 2, false),  -- game 8
  ('Jason Wilks',       2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Jason Wilks',       2, 'Middlesbrough',        'West Bromwich Albion', 1, 2, false),  -- game 10
  ('Jason Wilks',       2, 'Liverpool',            'Nottingham Forest',    2, 0, true ),  -- game 11
  ('Jason Wilks',       2, 'AFC Bournemouth',      'Everton',              1, 1, false),  -- game 12
  ('Jason Wilks',       2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Jason Wilks',       2, 'Tottenham Hotspur',    'Newcastle United',     1, 2, false),  -- game 14
  ('Jason Wilks',       2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Jason Wilks',       3, 'Ipswich Town',         'Liverpool',            1, 2, false),  -- game 16
  ('Jason Wilks',       3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('Jason Wilks',       3, 'Brentford',            'Sunderland',           1, 1, false),  -- game 18
  ('Jason Wilks',       3, 'Brighton Hove Albion', 'Leeds United',         3, 1, false),  -- game 19
  ('Jason Wilks',       3, 'Fulham',               'Crystal Palace',       1, 1, false),  -- game 20
  ('Jason Wilks',       3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('Jason Wilks',       3, 'Nottingham Forest',    'Tottenham Hotspur',    2, 1, false),  -- game 22
  ('Jason Wilks',       3, 'Hull City',            'Aston Villa',          2, 1, false),  -- game 23
  ('Jason Wilks',       4, 'West Ham United',      'Wrexham',              2, 0, false),  -- game 24
  ('Jason Wilks',       4, 'Aston Villa',          'Nottingham Forest',    1, 1, false),  -- game 25
  ('Jason Wilks',       4, 'AFC Bournemouth',      'Brentford',            2, 1, false),  -- game 26
  ('Jason Wilks',       4, 'Chelsea',              'Hull City',            3, 1, false),  -- game 27
  ('Jason Wilks',       4, 'Crystal Palace',       'Ipswich Town',         2, 0, false),  -- game 28
  ('Jason Wilks',       4, 'Liverpool',            'Fulham',               3, 1, true ),  -- game 29
  ('Jason Wilks',       4, 'Tottenham Hotspur',    'Everton',              1, 1, false),  -- game 30
  ('Jason Wilks',       4, 'Sunderland',           'Arsenal',              0, 3, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 13: XR219 (Ben Watson) (47)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Ben Watson',        1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Ben Watson',        1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Ben Watson',        1, 'Hull City',            'Manchester United',    0, 2, false),  -- game 3
  ('Ben Watson',        1, 'Everton',              'Crystal Palace',       2, 1, false),  -- game 4
  ('Ben Watson',        1, 'Ipswich Town',         'Sunderland',           2, 1, false),  -- game 5
  ('Ben Watson',        1, 'Nottingham Forest',    'Leeds United',         1, 2, false),  -- game 6
  ('Ben Watson',        1, 'Brentford',            'Tottenham Hotspur',    2, 3, false),  -- game 7
  ('Ben Watson',        2, 'Crystal Palace',       'Manchester City',      1, 2, true ),  -- game 8
  ('Ben Watson',        2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Ben Watson',        2, 'Middlesbrough',        'West Bromwich Albion', 2, 1, false),  -- game 10
  ('Ben Watson',        2, 'Liverpool',            'Nottingham Forest',    2, 1, false),  -- game 11
  ('Ben Watson',        2, 'AFC Bournemouth',      'Everton',              2, 2, false),  -- game 12
  ('Ben Watson',        2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Ben Watson',        2, 'Tottenham Hotspur',    'Newcastle United',     2, 1, false),  -- game 14
  ('Ben Watson',        2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Ben Watson',        3, 'Ipswich Town',         'Liverpool',            2, 2, false),  -- game 16
  ('Ben Watson',        3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('Ben Watson',        3, 'Brentford',            'Sunderland',           2, 1, false),  -- game 18
  ('Ben Watson',        3, 'Brighton Hove Albion', 'Leeds United',         2, 2, false),  -- game 19
  ('Ben Watson',        3, 'Fulham',               'Crystal Palace',       2, 1, false),  -- game 20
  ('Ben Watson',        3, 'Manchester City',      'Coventry City',        3, 1, false),  -- game 21
  ('Ben Watson',        3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 2, false),  -- game 22
  ('Ben Watson',        3, 'Hull City',            'Aston Villa',          1, 2, true ),  -- game 23
  ('Ben Watson',        4, 'West Ham United',      'Wrexham',              2, 1, true ),  -- game 24
  ('Ben Watson',        4, 'Aston Villa',          'Nottingham Forest',    2, 1, false),  -- game 25
  ('Ben Watson',        4, 'AFC Bournemouth',      'Brentford',            2, 1, false),  -- game 26
  ('Ben Watson',        4, 'Chelsea',              'Hull City',            2, 1, false),  -- game 27
  ('Ben Watson',        4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('Ben Watson',        4, 'Liverpool',            'Fulham',               3, 2, false),  -- game 29
  ('Ben Watson',        4, 'Tottenham Hotspur',    'Everton',              2, 1, false),  -- game 30
  ('Ben Watson',        4, 'Sunderland',           'Arsenal',              1, 2, false),  -- game 31
  ('Ben Watson',        5, 'Brentford',            'Chelsea',              1, 3, false),  -- game 32
  ('Ben Watson',        5, 'Bristol City',         'Watford',              2, 0, true ),  -- game 33
  ('Ben Watson',        5, 'Tottenham Hotspur',    'Aston Villa',          2, 2, false),  -- game 34
  ('Ben Watson',        5, 'Brighton Hove Albion', 'Arsenal',              1, 2, false),  -- game 35
  ('Ben Watson',        5, 'Everton',              'Ipswich Town',         2, 1, false),  -- game 36
  ('Ben Watson',        5, 'Millwall',             'West Ham United',      2, 1, false),  -- game 37
  ('Ben Watson',        5, 'Wrexham',              'Southampton',          2, 1, false),  -- game 38
  ('Ben Watson',        5, 'Newcastle United',     'Hull City',            2, 1, false),  -- game 39
  ('Ben Watson',        5, 'Nottingham Forest',    'Coventry City',        3, 1, false),  -- game 40
  ('Ben Watson',        6, 'Georgia',              'Northern Ireland',     1, 1, false),  -- game 41
  ('Ben Watson',        6, 'Italy',                'Belgium',              2, 1, true ),  -- game 42
  ('Ben Watson',        6, 'Turkey',               'France',               1, 2, false),  -- game 43
  ('Ben Watson',        6, 'Slovenia',             'Scotland',             2, 1, false),  -- game 44
  ('Ben Watson',        6, 'San Marino',           'Finland',              2, 0, false),  -- game 45
  ('Ben Watson',        6, 'Czech Republic',       'Croatia',              2, 1, false),  -- game 46
  ('Ben Watson',        6, 'England',              'Spain',                2, 3, false)  -- game 47
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 14: PeaNUFC (Penny Watson) (47)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Penny Watson',      1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Penny Watson',      1, 'Birmingham City',      'Bristol City',         2, 2, false),  -- game 2
  ('Penny Watson',      1, 'Hull City',            'Manchester United',    0, 2, false),  -- game 3
  ('Penny Watson',      1, 'Everton',              'Crystal Palace',       2, 2, false),  -- game 4
  ('Penny Watson',      1, 'Ipswich Town',         'Sunderland',           1, 2, false),  -- game 5
  ('Penny Watson',      1, 'Nottingham Forest',    'Leeds United',         1, 3, false),  -- game 6
  ('Penny Watson',      1, 'Brentford',            'Tottenham Hotspur',    1, 2, false),  -- game 7
  ('Penny Watson',      2, 'Crystal Palace',       'Manchester City',      1, 3, false),  -- game 8
  ('Penny Watson',      2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Penny Watson',      2, 'Middlesbrough',        'West Bromwich Albion', 2, 0, false),  -- game 10
  ('Penny Watson',      2, 'Liverpool',            'Nottingham Forest',    2, 1, false),  -- game 11
  ('Penny Watson',      2, 'AFC Bournemouth',      'Everton',              2, 1, false),  -- game 12
  ('Penny Watson',      2, 'Coventry City',        'Hull City',            2, 0, false),  -- game 13
  ('Penny Watson',      2, 'Tottenham Hotspur',    'Newcastle United',     3, 1, false),  -- game 14
  ('Penny Watson',      2, 'Watford',              'West Ham United',      0, 2, true ),  -- game 15
  ('Penny Watson',      3, 'Ipswich Town',         'Liverpool',            1, 2, false),  -- game 16
  ('Penny Watson',      3, 'Newcastle United',     'AFC Bournemouth',      2, 2, false),  -- game 17
  ('Penny Watson',      3, 'Brentford',            'Sunderland',           3, 2, false),  -- game 18
  ('Penny Watson',      3, 'Brighton Hove Albion', 'Leeds United',         0, 2, false),  -- game 19
  ('Penny Watson',      3, 'Fulham',               'Crystal Palace',       1, 3, false),  -- game 20
  ('Penny Watson',      3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('Penny Watson',      3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 3, false),  -- game 22
  ('Penny Watson',      3, 'Hull City',            'Aston Villa',          0, 2, false),  -- game 23
  ('Penny Watson',      4, 'West Ham United',      'Wrexham',              2, 2, false),  -- game 24
  ('Penny Watson',      4, 'Aston Villa',          'Nottingham Forest',    1, 2, false),  -- game 25
  ('Penny Watson',      4, 'AFC Bournemouth',      'Brentford',            2, 2, false),  -- game 26
  ('Penny Watson',      4, 'Chelsea',              'Hull City',            2, 0, false),  -- game 27
  ('Penny Watson',      4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('Penny Watson',      4, 'Liverpool',            'Fulham',               3, 1, false),  -- game 29
  ('Penny Watson',      4, 'Tottenham Hotspur',    'Everton',              2, 1, false),  -- game 30
  ('Penny Watson',      4, 'Sunderland',           'Arsenal',              0, 3, true ),  -- game 31
  ('Penny Watson',      5, 'Brentford',            'Chelsea',              1, 3, false),  -- game 32
  ('Penny Watson',      5, 'Bristol City',         'Watford',              1, 1, false),  -- game 33
  ('Penny Watson',      5, 'Tottenham Hotspur',    'Aston Villa',          2, 2, false),  -- game 34
  ('Penny Watson',      5, 'Brighton Hove Albion', 'Arsenal',              0, 2, false),  -- game 35
  ('Penny Watson',      5, 'Everton',              'Ipswich Town',         2, 1, false),  -- game 36
  ('Penny Watson',      5, 'Millwall',             'West Ham United',      2, 3, false),  -- game 37
  ('Penny Watson',      5, 'Wrexham',              'Southampton',          2, 1, false),  -- game 38
  ('Penny Watson',      5, 'Newcastle United',     'Hull City',            2, 1, false),  -- game 39
  ('Penny Watson',      5, 'Nottingham Forest',    'Coventry City',        2, 0, true ),  -- game 40
  ('Penny Watson',      6, 'Georgia',              'Northern Ireland',     2, 2, false),  -- game 41
  ('Penny Watson',      6, 'Italy',                'Belgium',              2, 2, false),  -- game 42
  ('Penny Watson',      6, 'Turkey',               'France',               0, 3, false),  -- game 43
  ('Penny Watson',      6, 'Slovenia',             'Scotland',             2, 1, false),  -- game 44
  ('Penny Watson',      6, 'San Marino',           'Finland',              1, 2, false),  -- game 45
  ('Penny Watson',      6, 'Czech Republic',       'Croatia',              2, 3, false),  -- game 46
  ('Penny Watson',      6, 'England',              'Spain',                2, 3, true )  -- game 47
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 15: Darth's Raiders (Raymond Watson) (47)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Raymond Watson',    1, 'Arsenal',              'Coventry City',        3, 1, true ),  -- game 1
  ('Raymond Watson',    1, 'Birmingham City',      'Bristol City',         2, 2, false),  -- game 2
  ('Raymond Watson',    1, 'Hull City',            'Manchester United',    1, 2, false),  -- game 3
  ('Raymond Watson',    1, 'Everton',              'Crystal Palace',       2, 1, false),  -- game 4
  ('Raymond Watson',    1, 'Ipswich Town',         'Sunderland',           1, 1, false),  -- game 5
  ('Raymond Watson',    1, 'Nottingham Forest',    'Leeds United',         2, 2, false),  -- game 6
  ('Raymond Watson',    1, 'Brentford',            'Tottenham Hotspur',    1, 2, false),  -- game 7
  ('Raymond Watson',    2, 'Crystal Palace',       'Manchester City',      1, 2, false),  -- game 8
  ('Raymond Watson',    2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Raymond Watson',    2, 'Middlesbrough',        'West Bromwich Albion', 2, 1, false),  -- game 10
  ('Raymond Watson',    2, 'Liverpool',            'Nottingham Forest',    2, 2, true ),  -- game 11
  ('Raymond Watson',    2, 'AFC Bournemouth',      'Everton',              1, 2, false),  -- game 12
  ('Raymond Watson',    2, 'Coventry City',        'Hull City',            1, 1, false),  -- game 13
  ('Raymond Watson',    2, 'Tottenham Hotspur',    'Newcastle United',     2, 1, false),  -- game 14
  ('Raymond Watson',    2, 'Watford',              'West Ham United',      2, 1, false),  -- game 15
  ('Raymond Watson',    3, 'Ipswich Town',         'Liverpool',            2, 2, false),  -- game 16
  ('Raymond Watson',    3, 'Newcastle United',     'AFC Bournemouth',      1, 0, false),  -- game 17
  ('Raymond Watson',    3, 'Brentford',            'Sunderland',           1, 1, false),  -- game 18
  ('Raymond Watson',    3, 'Brighton Hove Albion', 'Leeds United',         2, 2, false),  -- game 19
  ('Raymond Watson',    3, 'Fulham',               'Crystal Palace',       2, 1, false),  -- game 20
  ('Raymond Watson',    3, 'Manchester City',      'Coventry City',        2, 1, false),  -- game 21
  ('Raymond Watson',    3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 2, false),  -- game 22
  ('Raymond Watson',    3, 'Hull City',            'Aston Villa',          1, 2, true ),  -- game 23
  ('Raymond Watson',    4, 'West Ham United',      'Wrexham',              2, 1, false),  -- game 24
  ('Raymond Watson',    4, 'Aston Villa',          'Nottingham Forest',    2, 2, false),  -- game 25
  ('Raymond Watson',    4, 'AFC Bournemouth',      'Brentford',            1, 2, false),  -- game 26
  ('Raymond Watson',    4, 'Chelsea',              'Hull City',            2, 1, true ),  -- game 27
  ('Raymond Watson',    4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('Raymond Watson',    4, 'Liverpool',            'Fulham',               3, 1, false),  -- game 29
  ('Raymond Watson',    4, 'Tottenham Hotspur',    'Everton',              1, 1, false),  -- game 30
  ('Raymond Watson',    4, 'Sunderland',           'Arsenal',              1, 2, false),  -- game 31
  ('Raymond Watson',    5, 'Brentford',            'Chelsea',              2, 2, false),  -- game 32
  ('Raymond Watson',    5, 'Bristol City',         'Watford',              2, 1, true ),  -- game 33
  ('Raymond Watson',    5, 'Tottenham Hotspur',    'Aston Villa',          2, 2, false),  -- game 34
  ('Raymond Watson',    5, 'Brighton Hove Albion', 'Arsenal',              0, 1, false),  -- game 35
  ('Raymond Watson',    5, 'Everton',              'Ipswich Town',         2, 1, false),  -- game 36
  ('Raymond Watson',    5, 'Millwall',             'West Ham United',      1, 1, false),  -- game 37
  ('Raymond Watson',    5, 'Wrexham',              'Southampton',          2, 1, false),  -- game 38
  ('Raymond Watson',    5, 'Newcastle United',     'Hull City',            2, 2, false),  -- game 39
  ('Raymond Watson',    5, 'Nottingham Forest',    'Coventry City',        2, 1, false),  -- game 40
  ('Raymond Watson',    6, 'Georgia',              'Northern Ireland',     1, 0, false),  -- game 41
  ('Raymond Watson',    6, 'Italy',                'Belgium',              2, 2, false),  -- game 42
  ('Raymond Watson',    6, 'Turkey',               'France',               1, 2, true ),  -- game 43
  ('Raymond Watson',    6, 'Slovenia',             'Scotland',             1, 1, false),  -- game 44
  ('Raymond Watson',    6, 'San Marino',           'Finland',              0, 2, false),  -- game 45
  ('Raymond Watson',    6, 'Czech Republic',       'Croatia',              0, 1, false),  -- game 46
  ('Raymond Watson',    6, 'England',              'Spain',                1, 1, false)  -- game 47
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 16: Taking The Mikel (Ria Merchant) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Ria Merchant',      1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Ria Merchant',      1, 'Birmingham City',      'Bristol City',         1, 0, false),  -- game 2
  ('Ria Merchant',      1, 'Hull City',            'Manchester United',    1, 2, false),  -- game 3
  ('Ria Merchant',      1, 'Everton',              'Crystal Palace',       1, 2, false),  -- game 4
  ('Ria Merchant',      1, 'Ipswich Town',         'Sunderland',           0, 2, false),  -- game 5
  ('Ria Merchant',      1, 'Nottingham Forest',    'Leeds United',         1, 1, false),  -- game 6
  ('Ria Merchant',      1, 'Brentford',            'Tottenham Hotspur',    2, 2, false),  -- game 7
  ('Ria Merchant',      2, 'Crystal Palace',       'Manchester City',      1, 2, true ),  -- game 8
  ('Ria Merchant',      2, 'Wrexham',              'Birmingham City',      1, 1, false),  -- game 9
  ('Ria Merchant',      2, 'Middlesbrough',        'West Bromwich Albion', 2, 1, false),  -- game 10
  ('Ria Merchant',      2, 'Liverpool',            'Nottingham Forest',    2, 1, false),  -- game 11
  ('Ria Merchant',      2, 'AFC Bournemouth',      'Everton',              0, 1, false),  -- game 12
  ('Ria Merchant',      2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Ria Merchant',      2, 'Tottenham Hotspur',    'Newcastle United',     1, 1, false),  -- game 14
  ('Ria Merchant',      2, 'Watford',              'West Ham United',      2, 0, false),  -- game 15
  ('Ria Merchant',      3, 'Ipswich Town',         'Liverpool',            1, 2, false),  -- game 16
  ('Ria Merchant',      3, 'Newcastle United',     'AFC Bournemouth',      2, 0, false),  -- game 17
  ('Ria Merchant',      3, 'Brentford',            'Sunderland',           1, 0, false),  -- game 18
  ('Ria Merchant',      3, 'Brighton Hove Albion', 'Leeds United',         1, 1, false),  -- game 19
  ('Ria Merchant',      3, 'Fulham',               'Crystal Palace',       1, 0, false),  -- game 20
  ('Ria Merchant',      3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('Ria Merchant',      3, 'Nottingham Forest',    'Tottenham Hotspur',    2, 1, false),  -- game 22
  ('Ria Merchant',      3, 'Hull City',            'Aston Villa',          2, 0, false),  -- game 23
  ('Ria Merchant',      4, 'West Ham United',      'Wrexham',              2, 0, false),  -- game 24
  ('Ria Merchant',      4, 'Aston Villa',          'Nottingham Forest',    1, 1, false),  -- game 25
  ('Ria Merchant',      4, 'AFC Bournemouth',      'Brentford',            1, 2, false),  -- game 26
  ('Ria Merchant',      4, 'Chelsea',              'Hull City',            2, 1, false),  -- game 27
  ('Ria Merchant',      4, 'Crystal Palace',       'Ipswich Town',         2, 0, false),  -- game 28
  ('Ria Merchant',      4, 'Liverpool',            'Fulham',               3, 1, false),  -- game 29
  ('Ria Merchant',      4, 'Tottenham Hotspur',    'Everton',              1, 2, false),  -- game 30
  ('Ria Merchant',      4, 'Sunderland',           'Arsenal',              1, 3, true )  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 17: Banan Anan Doo Doo Doo Doo Doo (Liam Merchant) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Liam Merchant',     1, 'Arsenal',              'Coventry City',        3, 1, true ),  -- game 1
  ('Liam Merchant',     1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Liam Merchant',     1, 'Hull City',            'Manchester United',    0, 2, false),  -- game 3
  ('Liam Merchant',     1, 'Everton',              'Crystal Palace',       1, 1, false),  -- game 4
  ('Liam Merchant',     1, 'Ipswich Town',         'Sunderland',           1, 2, false),  -- game 5
  ('Liam Merchant',     1, 'Nottingham Forest',    'Leeds United',         2, 1, false),  -- game 6
  ('Liam Merchant',     1, 'Brentford',            'Tottenham Hotspur',    1, 3, false),  -- game 7
  ('Liam Merchant',     2, 'Crystal Palace',       'Manchester City',      1, 2, false),  -- game 8
  ('Liam Merchant',     2, 'Wrexham',              'Birmingham City',      2, 1, true ),  -- game 9
  ('Liam Merchant',     2, 'Middlesbrough',        'West Bromwich Albion', 1, 1, false),  -- game 10
  ('Liam Merchant',     2, 'Liverpool',            'Nottingham Forest',    2, 0, false),  -- game 11
  ('Liam Merchant',     2, 'AFC Bournemouth',      'Everton',              0, 1, false),  -- game 12
  ('Liam Merchant',     2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Liam Merchant',     2, 'Tottenham Hotspur',    'Newcastle United',     2, 0, false),  -- game 14
  ('Liam Merchant',     2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Liam Merchant',     3, 'Ipswich Town',         'Liverpool',            1, 3, false),  -- game 16
  ('Liam Merchant',     3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('Liam Merchant',     3, 'Brentford',            'Sunderland',           1, 1, false),  -- game 18
  ('Liam Merchant',     3, 'Brighton Hove Albion', 'Leeds United',         1, 0, false),  -- game 19
  ('Liam Merchant',     3, 'Fulham',               'Crystal Palace',       1, 2, false),  -- game 20
  ('Liam Merchant',     3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('Liam Merchant',     3, 'Nottingham Forest',    'Tottenham Hotspur',    2, 0, false),  -- game 22
  ('Liam Merchant',     3, 'Hull City',            'Aston Villa',          0, 1, false),  -- game 23
  ('Liam Merchant',     4, 'West Ham United',      'Wrexham',              2, 1, false),  -- game 24
  ('Liam Merchant',     4, 'Aston Villa',          'Nottingham Forest',    1, 1, false),  -- game 25
  ('Liam Merchant',     4, 'AFC Bournemouth',      'Brentford',            1, 0, false),  -- game 26
  ('Liam Merchant',     4, 'Chelsea',              'Hull City',            3, 0, true ),  -- game 27
  ('Liam Merchant',     4, 'Crystal Palace',       'Ipswich Town',         2, 0, false),  -- game 28
  ('Liam Merchant',     4, 'Liverpool',            'Fulham',               2, 0, false),  -- game 29
  ('Liam Merchant',     4, 'Tottenham Hotspur',    'Everton',              1, 2, false),  -- game 30
  ('Liam Merchant',     4, 'Sunderland',           'Arsenal',              1, 3, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 18: Mind The Gap (Ian Cantwell) (47)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Ian Cantwell',      1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Ian Cantwell',      1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Ian Cantwell',      1, 'Hull City',            'Manchester United',    1, 2, false),  -- game 3
  ('Ian Cantwell',      1, 'Everton',              'Crystal Palace',       1, 1, false),  -- game 4
  ('Ian Cantwell',      1, 'Ipswich Town',         'Sunderland',           0, 2, false),  -- game 5
  ('Ian Cantwell',      1, 'Nottingham Forest',    'Leeds United',         2, 1, false),  -- game 6
  ('Ian Cantwell',      1, 'Brentford',            'Tottenham Hotspur',    1, 2, false),  -- game 7
  ('Ian Cantwell',      2, 'Crystal Palace',       'Manchester City',      1, 3, true ),  -- game 8
  ('Ian Cantwell',      2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Ian Cantwell',      2, 'Middlesbrough',        'West Bromwich Albion', 2, 2, false),  -- game 10
  ('Ian Cantwell',      2, 'Liverpool',            'Nottingham Forest',    2, 1, false),  -- game 11
  ('Ian Cantwell',      2, 'AFC Bournemouth',      'Everton',              0, 1, false),  -- game 12
  ('Ian Cantwell',      2, 'Coventry City',        'Hull City',            1, 1, false),  -- game 13
  ('Ian Cantwell',      2, 'Tottenham Hotspur',    'Newcastle United',     2, 0, false),  -- game 14
  ('Ian Cantwell',      2, 'Watford',              'West Ham United',      1, 3, false),  -- game 15
  ('Ian Cantwell',      3, 'Ipswich Town',         'Liverpool',            0, 2, false),  -- game 16
  ('Ian Cantwell',      3, 'Newcastle United',     'AFC Bournemouth',      1, 1, false),  -- game 17
  ('Ian Cantwell',      3, 'Brentford',            'Sunderland',           0, 0, false),  -- game 18
  ('Ian Cantwell',      3, 'Brighton Hove Albion', 'Leeds United',         2, 1, false),  -- game 19
  ('Ian Cantwell',      3, 'Fulham',               'Crystal Palace',       1, 0, false),  -- game 20
  ('Ian Cantwell',      3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('Ian Cantwell',      3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 2, false),  -- game 22
  ('Ian Cantwell',      3, 'Hull City',            'Aston Villa',          0, 1, false),  -- game 23
  ('Ian Cantwell',      4, 'West Ham United',      'Wrexham',              3, 1, false),  -- game 24
  ('Ian Cantwell',      4, 'Aston Villa',          'Nottingham Forest',    2, 1, false),  -- game 25
  ('Ian Cantwell',      4, 'AFC Bournemouth',      'Brentford',            0, 1, false),  -- game 26
  ('Ian Cantwell',      4, 'Chelsea',              'Hull City',            2, 1, false),  -- game 27
  ('Ian Cantwell',      4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('Ian Cantwell',      4, 'Liverpool',            'Fulham',               3, 1, true ),  -- game 29
  ('Ian Cantwell',      4, 'Tottenham Hotspur',    'Everton',              1, 1, false),  -- game 30
  ('Ian Cantwell',      4, 'Sunderland',           'Arsenal',              0, 2, false),  -- game 31
  ('Ian Cantwell',      5, 'Brentford',            'Chelsea',              1, 2, false),  -- game 32
  ('Ian Cantwell',      5, 'Bristol City',         'Watford',              2, 1, false),  -- game 33
  ('Ian Cantwell',      5, 'Tottenham Hotspur',    'Aston Villa',          1, 1, false),  -- game 34
  ('Ian Cantwell',      5, 'Brighton Hove Albion', 'Arsenal',              1, 2, true ),  -- game 35
  ('Ian Cantwell',      5, 'Everton',              'Ipswich Town',         2, 0, false),  -- game 36
  ('Ian Cantwell',      5, 'Millwall',             'West Ham United',      2, 3, false),  -- game 37
  ('Ian Cantwell',      5, 'Wrexham',              'Southampton',          1, 3, false),  -- game 38
  ('Ian Cantwell',      5, 'Newcastle United',     'Hull City',            2, 1, false),  -- game 39
  ('Ian Cantwell',      5, 'Nottingham Forest',    'Coventry City',        1, 1, false),  -- game 40
  ('Ian Cantwell',      6, 'Georgia',              'Northern Ireland',     2, 0, false),  -- game 41
  ('Ian Cantwell',      6, 'Italy',                'Belgium',              2, 1, false),  -- game 42
  ('Ian Cantwell',      6, 'Turkey',               'France',               1, 3, false),  -- game 43
  ('Ian Cantwell',      6, 'Slovenia',             'Scotland',             1, 1, false),  -- game 44
  ('Ian Cantwell',      6, 'San Marino',           'Finland',              0, 4, false),  -- game 45
  ('Ian Cantwell',      6, 'Czech Republic',       'Croatia',              0, 2, true ),  -- game 46
  ('Ian Cantwell',      6, 'England',              'Spain',                3, 1, false)  -- game 47
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 20: Some Jaouen And Some You Lose (Gary Morgan) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Gary Morgan',       1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Gary Morgan',       1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Gary Morgan',       1, 'Hull City',            'Manchester United',    1, 2, false),  -- game 3
  ('Gary Morgan',       1, 'Everton',              'Crystal Palace',       2, 1, false),  -- game 4
  ('Gary Morgan',       1, 'Ipswich Town',         'Sunderland',           1, 1, false),  -- game 5
  ('Gary Morgan',       1, 'Nottingham Forest',    'Leeds United',         2, 1, false),  -- game 6
  ('Gary Morgan',       1, 'Brentford',            'Tottenham Hotspur',    1, 2, false),  -- game 7
  ('Gary Morgan',       2, 'Crystal Palace',       'Manchester City',      1, 2, false),  -- game 8
  ('Gary Morgan',       2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Gary Morgan',       2, 'Middlesbrough',        'West Bromwich Albion', 2, 0, false),  -- game 10
  ('Gary Morgan',       2, 'Liverpool',            'Nottingham Forest',    3, 1, true ),  -- game 11
  ('Gary Morgan',       2, 'AFC Bournemouth',      'Everton',              2, 2, false),  -- game 12
  ('Gary Morgan',       2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Gary Morgan',       2, 'Tottenham Hotspur',    'Newcastle United',     1, 2, false),  -- game 14
  ('Gary Morgan',       2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Gary Morgan',       3, 'Ipswich Town',         'Liverpool',            1, 3, false),  -- game 16
  ('Gary Morgan',       3, 'Newcastle United',     'AFC Bournemouth',      3, 1, true ),  -- game 17
  ('Gary Morgan',       3, 'Brentford',            'Sunderland',           2, 0, false),  -- game 18
  ('Gary Morgan',       3, 'Brighton Hove Albion', 'Leeds United',         2, 2, false),  -- game 19
  ('Gary Morgan',       3, 'Fulham',               'Crystal Palace',       1, 0, false),  -- game 20
  ('Gary Morgan',       3, 'Manchester City',      'Coventry City',        4, 0, false),  -- game 21
  ('Gary Morgan',       3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 2, false),  -- game 22
  ('Gary Morgan',       3, 'Hull City',            'Aston Villa',          0, 0, false),  -- game 23
  ('Gary Morgan',       4, 'West Ham United',      'Wrexham',              2, 2, false),  -- game 24
  ('Gary Morgan',       4, 'Aston Villa',          'Nottingham Forest',    2, 0, false),  -- game 25
  ('Gary Morgan',       4, 'AFC Bournemouth',      'Brentford',            2, 1, false),  -- game 26
  ('Gary Morgan',       4, 'Chelsea',              'Hull City',            3, 1, false),  -- game 27
  ('Gary Morgan',       4, 'Crystal Palace',       'Ipswich Town',         2, 0, false),  -- game 28
  ('Gary Morgan',       4, 'Liverpool',            'Fulham',               3, 0, false),  -- game 29
  ('Gary Morgan',       4, 'Tottenham Hotspur',    'Everton',              1, 2, false),  -- game 30
  ('Gary Morgan',       4, 'Sunderland',           'Arsenal',              0, 2, true )  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 21: The Dukes (Macauley Duke) (47)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Macauley Duke',     1, 'Arsenal',              'Coventry City',        3, 0, false),  -- game 1
  ('Macauley Duke',     1, 'Birmingham City',      'Bristol City',         1, 1, false),  -- game 2
  ('Macauley Duke',     1, 'Hull City',            'Manchester United',    0, 2, true ),  -- game 3
  ('Macauley Duke',     1, 'Everton',              'Crystal Palace',       1, 1, false),  -- game 4
  ('Macauley Duke',     1, 'Ipswich Town',         'Sunderland',           0, 1, false),  -- game 5
  ('Macauley Duke',     1, 'Nottingham Forest',    'Leeds United',         1, 1, false),  -- game 6
  ('Macauley Duke',     1, 'Brentford',            'Tottenham Hotspur',    0, 2, false),  -- game 7
  ('Macauley Duke',     2, 'Crystal Palace',       'Manchester City',      0, 3, true ),  -- game 8
  ('Macauley Duke',     2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Macauley Duke',     2, 'Middlesbrough',        'West Bromwich Albion', 2, 0, false),  -- game 10
  ('Macauley Duke',     2, 'Liverpool',            'Nottingham Forest',    2, 1, false),  -- game 11
  ('Macauley Duke',     2, 'AFC Bournemouth',      'Everton',              1, 0, false),  -- game 12
  ('Macauley Duke',     2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Macauley Duke',     2, 'Tottenham Hotspur',    'Newcastle United',     2, 0, false),  -- game 14
  ('Macauley Duke',     2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Macauley Duke',     3, 'Ipswich Town',         'Liverpool',            0, 3, false),  -- game 16
  ('Macauley Duke',     3, 'Newcastle United',     'AFC Bournemouth',      2, 1, true ),  -- game 17
  ('Macauley Duke',     3, 'Brentford',            'Sunderland',           0, 0, false),  -- game 18
  ('Macauley Duke',     3, 'Brighton Hove Albion', 'Leeds United',         0, 1, false),  -- game 19
  ('Macauley Duke',     3, 'Fulham',               'Crystal Palace',       3, 1, false),  -- game 20
  ('Macauley Duke',     3, 'Manchester City',      'Coventry City',        5, 0, false),  -- game 21
  ('Macauley Duke',     3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 1, false),  -- game 22
  ('Macauley Duke',     3, 'Hull City',            'Aston Villa',          1, 3, false),  -- game 23
  ('Macauley Duke',     4, 'West Ham United',      'Wrexham',              2, 1, false),  -- game 24
  ('Macauley Duke',     4, 'Aston Villa',          'Nottingham Forest',    1, 0, false),  -- game 25
  ('Macauley Duke',     4, 'AFC Bournemouth',      'Brentford',            1, 0, false),  -- game 26
  ('Macauley Duke',     4, 'Chelsea',              'Hull City',            3, 0, false),  -- game 27
  ('Macauley Duke',     4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('Macauley Duke',     4, 'Liverpool',            'Fulham',               3, 1, true ),  -- game 29
  ('Macauley Duke',     4, 'Tottenham Hotspur',    'Everton',              2, 1, false),  -- game 30
  ('Macauley Duke',     4, 'Sunderland',           'Arsenal',              0, 2, false),  -- game 31
  ('Macauley Duke',     5, 'Brentford',            'Chelsea',              0, 1, false),  -- game 32
  ('Macauley Duke',     5, 'Bristol City',         'Watford',              2, 1, false),  -- game 33
  ('Macauley Duke',     5, 'Tottenham Hotspur',    'Aston Villa',          2, 2, false),  -- game 34
  ('Macauley Duke',     5, 'Brighton Hove Albion', 'Arsenal',              1, 2, true ),  -- game 35
  ('Macauley Duke',     5, 'Everton',              'Ipswich Town',         1, 0, false),  -- game 36
  ('Macauley Duke',     5, 'Millwall',             'West Ham United',      1, 1, false),  -- game 37
  ('Macauley Duke',     5, 'Wrexham',              'Southampton',          1, 0, false),  -- game 38
  ('Macauley Duke',     5, 'Newcastle United',     'Hull City',            2, 1, false),  -- game 39
  ('Macauley Duke',     5, 'Nottingham Forest',    'Coventry City',        1, 1, false),  -- game 40
  ('Macauley Duke',     6, 'Georgia',              'Northern Ireland',     2, 1, false),  -- game 41
  ('Macauley Duke',     6, 'Italy',                'Belgium',              1, 3, false),  -- game 42
  ('Macauley Duke',     6, 'Turkey',               'France',               0, 2, false),  -- game 43
  ('Macauley Duke',     6, 'Slovenia',             'Scotland',             1, 1, false),  -- game 44
  ('Macauley Duke',     6, 'San Marino',           'Finland',              0, 4, true ),  -- game 45
  ('Macauley Duke',     6, 'Czech Republic',       'Croatia',              1, 2, false),  -- game 46
  ('Macauley Duke',     6, 'England',              'Spain',                1, 1, false)  -- game 47
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 22: Boksh-to-Boksh (Shabbir Boksh) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Shabbir Boksh',     1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Shabbir Boksh',     1, 'Birmingham City',      'Bristol City',         1, 1, false),  -- game 2
  ('Shabbir Boksh',     1, 'Hull City',            'Manchester United',    0, 2, false),  -- game 3
  ('Shabbir Boksh',     1, 'Everton',              'Crystal Palace',       1, 1, false),  -- game 4
  ('Shabbir Boksh',     1, 'Ipswich Town',         'Sunderland',           2, 1, false),  -- game 5
  ('Shabbir Boksh',     1, 'Nottingham Forest',    'Leeds United',         2, 1, false),  -- game 6
  ('Shabbir Boksh',     1, 'Brentford',            'Tottenham Hotspur',    1, 2, false),  -- game 7
  ('Shabbir Boksh',     2, 'Crystal Palace',       'Manchester City',      1, 3, true ),  -- game 8
  ('Shabbir Boksh',     2, 'Wrexham',              'Birmingham City',      1, 2, false),  -- game 9
  ('Shabbir Boksh',     2, 'Middlesbrough',        'West Bromwich Albion', 2, 1, false),  -- game 10
  ('Shabbir Boksh',     2, 'Liverpool',            'Nottingham Forest',    3, 1, false),  -- game 11
  ('Shabbir Boksh',     2, 'AFC Bournemouth',      'Everton',              2, 2, false),  -- game 12
  ('Shabbir Boksh',     2, 'Coventry City',        'Hull City',            1, 1, false),  -- game 13
  ('Shabbir Boksh',     2, 'Tottenham Hotspur',    'Newcastle United',     2, 3, false),  -- game 14
  ('Shabbir Boksh',     2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Shabbir Boksh',     3, 'Ipswich Town',         'Liverpool',            1, 3, false),  -- game 16
  ('Shabbir Boksh',     3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('Shabbir Boksh',     3, 'Brentford',            'Sunderland',           2, 0, false),  -- game 18
  ('Shabbir Boksh',     3, 'Brighton Hove Albion', 'Leeds United',         2, 1, false),  -- game 19
  ('Shabbir Boksh',     3, 'Fulham',               'Crystal Palace',       1, 1, false),  -- game 20
  ('Shabbir Boksh',     3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('Shabbir Boksh',     3, 'Nottingham Forest',    'Tottenham Hotspur',    2, 1, false),  -- game 22
  ('Shabbir Boksh',     3, 'Hull City',            'Aston Villa',          1, 1, false),  -- game 23
  ('Shabbir Boksh',     4, 'West Ham United',      'Wrexham',              2, 0, false),  -- game 24
  ('Shabbir Boksh',     4, 'Aston Villa',          'Nottingham Forest',    1, 1, false),  -- game 25
  ('Shabbir Boksh',     4, 'AFC Bournemouth',      'Brentford',            2, 2, false),  -- game 26
  ('Shabbir Boksh',     4, 'Chelsea',              'Hull City',            2, 1, false),  -- game 27
  ('Shabbir Boksh',     4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('Shabbir Boksh',     4, 'Liverpool',            'Fulham',               3, 1, true ),  -- game 29
  ('Shabbir Boksh',     4, 'Tottenham Hotspur',    'Everton',              1, 2, false),  -- game 30
  ('Shabbir Boksh',     4, 'Sunderland',           'Arsenal',              0, 2, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 23: Nancy Drew Your Predictions (Nancy Sharma) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Nancy Sharma',      1, 'Arsenal',              'Coventry City',        3, 1, false),  -- game 1
  ('Nancy Sharma',      1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Nancy Sharma',      1, 'Hull City',            'Manchester United',    1, 3, true ),  -- game 3
  ('Nancy Sharma',      1, 'Everton',              'Crystal Palace',       2, 3, false),  -- game 4
  ('Nancy Sharma',      1, 'Ipswich Town',         'Sunderland',           1, 2, false),  -- game 5
  ('Nancy Sharma',      1, 'Nottingham Forest',    'Leeds United',         0, 1, false),  -- game 6
  ('Nancy Sharma',      1, 'Brentford',            'Tottenham Hotspur',    2, 3, false),  -- game 7
  ('Nancy Sharma',      2, 'Crystal Palace',       'Manchester City',      2, 1, false),  -- game 8
  ('Nancy Sharma',      2, 'Wrexham',              'Birmingham City',      1, 3, true ),  -- game 9
  ('Nancy Sharma',      2, 'Middlesbrough',        'West Bromwich Albion', 2, 1, false),  -- game 10
  ('Nancy Sharma',      2, 'Liverpool',            'Nottingham Forest',    2, 3, false),  -- game 11
  ('Nancy Sharma',      2, 'AFC Bournemouth',      'Everton',              0, 2, false),  -- game 12
  ('Nancy Sharma',      2, 'Coventry City',        'Hull City',            1, 3, false),  -- game 13
  ('Nancy Sharma',      2, 'Tottenham Hotspur',    'Newcastle United',     1, 2, false),  -- game 14
  ('Nancy Sharma',      2, 'Watford',              'West Ham United',      3, 2, false),  -- game 15
  ('Nancy Sharma',      3, 'Ipswich Town',         'Liverpool',            1, 2, false),  -- game 16
  ('Nancy Sharma',      3, 'Newcastle United',     'AFC Bournemouth',      3, 1, false),  -- game 17
  ('Nancy Sharma',      3, 'Brentford',            'Sunderland',           2, 1, false),  -- game 18
  ('Nancy Sharma',      3, 'Brighton Hove Albion', 'Leeds United',         2, 2, true ),  -- game 19
  ('Nancy Sharma',      3, 'Fulham',               'Crystal Palace',       3, 2, false),  -- game 20
  ('Nancy Sharma',      3, 'Manchester City',      'Coventry City',        4, 2, false),  -- game 21
  ('Nancy Sharma',      3, 'Nottingham Forest',    'Tottenham Hotspur',    3, 1, false),  -- game 22
  ('Nancy Sharma',      3, 'Hull City',            'Aston Villa',          1, 3, false),  -- game 23
  ('Nancy Sharma',      4, 'West Ham United',      'Wrexham',              2, 3, false),  -- game 24
  ('Nancy Sharma',      4, 'Aston Villa',          'Nottingham Forest',    4, 2, false),  -- game 25
  ('Nancy Sharma',      4, 'AFC Bournemouth',      'Brentford',            2, 1, false),  -- game 26
  ('Nancy Sharma',      4, 'Chelsea',              'Hull City',            3, 2, false),  -- game 27
  ('Nancy Sharma',      4, 'Crystal Palace',       'Ipswich Town',         2, 3, false),  -- game 28
  ('Nancy Sharma',      4, 'Liverpool',            'Fulham',               3, 1, true ),  -- game 29
  ('Nancy Sharma',      4, 'Tottenham Hotspur',    'Everton',              2, 3, false),  -- game 30
  ('Nancy Sharma',      4, 'Sunderland',           'Arsenal',              1, 2, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 24: The Eagles Pitt Stop (Mirko Kola) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Mirko Kola',        1, 'Arsenal',              'Coventry City',        3, 1, true ),  -- game 1
  ('Mirko Kola',        1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Mirko Kola',        1, 'Hull City',            'Manchester United',    1, 2, false),  -- game 3
  ('Mirko Kola',        1, 'Everton',              'Crystal Palace',       1, 1, false),  -- game 4
  ('Mirko Kola',        1, 'Ipswich Town',         'Sunderland',           2, 1, false),  -- game 5
  ('Mirko Kola',        1, 'Nottingham Forest',    'Leeds United',         1, 2, false),  -- game 6
  ('Mirko Kola',        1, 'Brentford',            'Tottenham Hotspur',    1, 2, false),  -- game 7
  ('Mirko Kola',        2, 'Crystal Palace',       'Manchester City',      1, 3, false),  -- game 8
  ('Mirko Kola',        2, 'Wrexham',              'Birmingham City',      1, 2, false),  -- game 9
  ('Mirko Kola',        2, 'Middlesbrough',        'West Bromwich Albion', 1, 1, false),  -- game 10
  ('Mirko Kola',        2, 'Liverpool',            'Nottingham Forest',    3, 0, true ),  -- game 11
  ('Mirko Kola',        2, 'AFC Bournemouth',      'Everton',              2, 1, false),  -- game 12
  ('Mirko Kola',        2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Mirko Kola',        2, 'Tottenham Hotspur',    'Newcastle United',     2, 2, false),  -- game 14
  ('Mirko Kola',        2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Mirko Kola',        3, 'Ipswich Town',         'Liverpool',            1, 3, false),  -- game 16
  ('Mirko Kola',        3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('Mirko Kola',        3, 'Brentford',            'Sunderland',           2, 0, false),  -- game 18
  ('Mirko Kola',        3, 'Brighton Hove Albion', 'Leeds United',         2, 1, true ),  -- game 19
  ('Mirko Kola',        3, 'Fulham',               'Crystal Palace',       1, 1, false),  -- game 20
  ('Mirko Kola',        3, 'Manchester City',      'Coventry City',        4, 0, false),  -- game 21
  ('Mirko Kola',        3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 2, false),  -- game 22
  ('Mirko Kola',        3, 'Hull City',            'Aston Villa',          2, 1, false),  -- game 23
  ('Mirko Kola',        4, 'West Ham United',      'Wrexham',              3, 1, false),  -- game 24
  ('Mirko Kola',        4, 'Aston Villa',          'Nottingham Forest',    2, 1, false),  -- game 25
  ('Mirko Kola',        4, 'AFC Bournemouth',      'Brentford',            1, 2, false),  -- game 26
  ('Mirko Kola',        4, 'Chelsea',              'Hull City',            3, 1, false),  -- game 27
  ('Mirko Kola',        4, 'Crystal Palace',       'Ipswich Town',         2, 1, true ),  -- game 28
  ('Mirko Kola',        4, 'Liverpool',            'Fulham',               2, 0, false),  -- game 29
  ('Mirko Kola',        4, 'Tottenham Hotspur',    'Everton',              2, 1, false),  -- game 30
  ('Mirko Kola',        4, 'Sunderland',           'Arsenal',              1, 3, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 25: TFC (Tony Styles) (47)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Tony Styles',       1, 'Arsenal',              'Coventry City',        1, 0, true ),  -- game 1
  ('Tony Styles',       1, 'Birmingham City',      'Bristol City',         1, 0, false),  -- game 2
  ('Tony Styles',       1, 'Hull City',            'Manchester United',    1, 0, false),  -- game 3
  ('Tony Styles',       1, 'Everton',              'Crystal Palace',       1, 0, false),  -- game 4
  ('Tony Styles',       1, 'Ipswich Town',         'Sunderland',           1, 0, false),  -- game 5
  ('Tony Styles',       1, 'Nottingham Forest',    'Leeds United',         1, 0, false),  -- game 6
  ('Tony Styles',       1, 'Brentford',            'Tottenham Hotspur',    1, 0, false),  -- game 7
  ('Tony Styles',       2, 'Crystal Palace',       'Manchester City',      0, 2, false),  -- game 8
  ('Tony Styles',       2, 'Wrexham',              'Birmingham City',      2, 2, false),  -- game 9
  ('Tony Styles',       2, 'Middlesbrough',        'West Bromwich Albion', 1, 2, false),  -- game 10
  ('Tony Styles',       2, 'Liverpool',            'Nottingham Forest',    2, 0, true ),  -- game 11
  ('Tony Styles',       2, 'AFC Bournemouth',      'Everton',              1, 1, false),  -- game 12
  ('Tony Styles',       2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Tony Styles',       2, 'Tottenham Hotspur',    'Newcastle United',     2, 1, false),  -- game 14
  ('Tony Styles',       2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Tony Styles',       3, 'Ipswich Town',         'Liverpool',            0, 2, false),  -- game 16
  ('Tony Styles',       3, 'Newcastle United',     'AFC Bournemouth',      1, 1, false),  -- game 17
  ('Tony Styles',       3, 'Brentford',            'Sunderland',           2, 0, true ),  -- game 18
  ('Tony Styles',       3, 'Brighton Hove Albion', 'Leeds United',         1, 1, false),  -- game 19
  ('Tony Styles',       3, 'Fulham',               'Crystal Palace',       2, 1, false),  -- game 20
  ('Tony Styles',       3, 'Manchester City',      'Coventry City',        3, 0, false),  -- game 21
  ('Tony Styles',       3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 2, false),  -- game 22
  ('Tony Styles',       3, 'Hull City',            'Aston Villa',          1, 1, false),  -- game 23
  ('Tony Styles',       4, 'West Ham United',      'Wrexham',              2, 1, false),  -- game 24
  ('Tony Styles',       4, 'Aston Villa',          'Nottingham Forest',    2, 0, false),  -- game 25
  ('Tony Styles',       4, 'AFC Bournemouth',      'Brentford',            2, 1, false),  -- game 26
  ('Tony Styles',       4, 'Chelsea',              'Hull City',            2, 0, false),  -- game 27
  ('Tony Styles',       4, 'Crystal Palace',       'Ipswich Town',         1, 1, false),  -- game 28
  ('Tony Styles',       4, 'Liverpool',            'Fulham',               2, 0, false),  -- game 29
  ('Tony Styles',       4, 'Tottenham Hotspur',    'Everton',              1, 1, false),  -- game 30
  ('Tony Styles',       4, 'Sunderland',           'Arsenal',              1, 2, true ),  -- game 31
  ('Tony Styles',       5, 'Brentford',            'Chelsea',              1, 2, false),  -- game 32
  ('Tony Styles',       5, 'Bristol City',         'Watford',              2, 0, false),  -- game 33
  ('Tony Styles',       5, 'Tottenham Hotspur',    'Aston Villa',          1, 1, false),  -- game 34
  ('Tony Styles',       5, 'Brighton Hove Albion', 'Arsenal',              1, 2, false),  -- game 35
  ('Tony Styles',       5, 'Everton',              'Ipswich Town',         2, 0, false),  -- game 36
  ('Tony Styles',       5, 'Millwall',             'West Ham United',      1, 1, false),  -- game 37
  ('Tony Styles',       5, 'Wrexham',              'Southampton',          1, 2, false),  -- game 38
  ('Tony Styles',       5, 'Newcastle United',     'Hull City',            0, 0, true ),  -- game 39
  ('Tony Styles',       5, 'Nottingham Forest',    'Coventry City',        2, 1, false),  -- game 40
  ('Tony Styles',       6, 'Georgia',              'Northern Ireland',     1, 2, false),  -- game 41
  ('Tony Styles',       6, 'Italy',                'Belgium',              1, 2, false),  -- game 42
  ('Tony Styles',       6, 'Turkey',               'France',               0, 2, true ),  -- game 43
  ('Tony Styles',       6, 'Slovenia',             'Scotland',             2, 1, false),  -- game 44
  ('Tony Styles',       6, 'San Marino',           'Finland',              0, 2, false),  -- game 45
  ('Tony Styles',       6, 'Czech Republic',       'Croatia',              0, 2, false),  -- game 46
  ('Tony Styles',       6, 'England',              'Spain',                1, 1, false)  -- game 47
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 26: Weah Better Than This (Jonathan Snaith) (40)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Jonathan Snaith',   1, 'Arsenal',              'Coventry City',        3, 0, false),  -- game 1
  ('Jonathan Snaith',   1, 'Birmingham City',      'Bristol City',         1, 1, false),  -- game 2
  ('Jonathan Snaith',   1, 'Hull City',            'Manchester United',    0, 2, true ),  -- game 3
  ('Jonathan Snaith',   1, 'Everton',              'Crystal Palace',       2, 1, false),  -- game 4
  ('Jonathan Snaith',   1, 'Ipswich Town',         'Sunderland',           1, 1, false),  -- game 5
  ('Jonathan Snaith',   1, 'Nottingham Forest',    'Leeds United',         1, 2, false),  -- game 6
  ('Jonathan Snaith',   1, 'Brentford',            'Tottenham Hotspur',    1, 2, false),  -- game 7
  ('Jonathan Snaith',   2, 'Crystal Palace',       'Manchester City',      1, 1, false),  -- game 8
  ('Jonathan Snaith',   2, 'Wrexham',              'Birmingham City',      2, 0, false),  -- game 9
  ('Jonathan Snaith',   2, 'Middlesbrough',        'West Bromwich Albion', 2, 1, false),  -- game 10
  ('Jonathan Snaith',   2, 'Liverpool',            'Nottingham Forest',    3, 1, false),  -- game 11
  ('Jonathan Snaith',   2, 'AFC Bournemouth',      'Everton',              1, 0, false),  -- game 12
  ('Jonathan Snaith',   2, 'Coventry City',        'Hull City',            1, 0, false),  -- game 13
  ('Jonathan Snaith',   2, 'Tottenham Hotspur',    'Newcastle United',     2, 1, false),  -- game 14
  ('Jonathan Snaith',   2, 'Watford',              'West Ham United',      1, 3, true ),  -- game 15
  ('Jonathan Snaith',   3, 'Ipswich Town',         'Liverpool',            0, 2, false),  -- game 16
  ('Jonathan Snaith',   3, 'Newcastle United',     'AFC Bournemouth',      3, 0, true ),  -- game 17
  ('Jonathan Snaith',   3, 'Brentford',            'Sunderland',           2, 0, false),  -- game 18
  ('Jonathan Snaith',   3, 'Brighton Hove Albion', 'Leeds United',         1, 1, false),  -- game 19
  ('Jonathan Snaith',   3, 'Fulham',               'Crystal Palace',       2, 1, false),  -- game 20
  ('Jonathan Snaith',   3, 'Manchester City',      'Coventry City',        5, 0, false),  -- game 21
  ('Jonathan Snaith',   3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 1, false),  -- game 22
  ('Jonathan Snaith',   3, 'Hull City',            'Aston Villa',          1, 2, false),  -- game 23
  ('Jonathan Snaith',   4, 'West Ham United',      'Wrexham',              2, 0, false),  -- game 24
  ('Jonathan Snaith',   4, 'Aston Villa',          'Nottingham Forest',    2, 1, false),  -- game 25
  ('Jonathan Snaith',   4, 'AFC Bournemouth',      'Brentford',            1, 1, false),  -- game 26
  ('Jonathan Snaith',   4, 'Chelsea',              'Hull City',            3, 0, true ),  -- game 27
  ('Jonathan Snaith',   4, 'Crystal Palace',       'Ipswich Town',         2, 0, false),  -- game 28
  ('Jonathan Snaith',   4, 'Liverpool',            'Fulham',               3, 1, false),  -- game 29
  ('Jonathan Snaith',   4, 'Tottenham Hotspur',    'Everton',              2, 0, false),  -- game 30
  ('Jonathan Snaith',   4, 'Sunderland',           'Arsenal',              0, 2, false),  -- game 31
  ('Jonathan Snaith',   5, 'Brentford',            'Chelsea',              1, 2, false),  -- game 32
  ('Jonathan Snaith',   5, 'Bristol City',         'Watford',              1, 2, false),  -- game 33
  ('Jonathan Snaith',   5, 'Tottenham Hotspur',    'Aston Villa',          2, 2, false),  -- game 34
  ('Jonathan Snaith',   5, 'Brighton Hove Albion', 'Arsenal',              1, 2, false),  -- game 35
  ('Jonathan Snaith',   5, 'Everton',              'Ipswich Town',         2, 1, false),  -- game 36
  ('Jonathan Snaith',   5, 'Millwall',             'West Ham United',      1, 2, false),  -- game 37
  ('Jonathan Snaith',   5, 'Wrexham',              'Southampton',          1, 1, false),  -- game 38
  ('Jonathan Snaith',   5, 'Newcastle United',     'Hull City',            3, 0, true ),  -- game 39
  ('Jonathan Snaith',   5, 'Nottingham Forest',    'Coventry City',        2, 0, false)  -- game 40
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 27: Victor Moses Lawn (Matthew Noble) (23)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Matthew Noble',     1, 'Arsenal',              'Coventry City',        4, 1, true ),  -- game 1
  ('Matthew Noble',     1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Matthew Noble',     1, 'Hull City',            'Manchester United',    1, 3, false),  -- game 3
  ('Matthew Noble',     1, 'Everton',              'Crystal Palace',       2, 0, false),  -- game 4
  ('Matthew Noble',     1, 'Ipswich Town',         'Sunderland',           1, 2, false),  -- game 5
  ('Matthew Noble',     1, 'Nottingham Forest',    'Leeds United',         3, 1, false),  -- game 6
  ('Matthew Noble',     1, 'Brentford',            'Tottenham Hotspur',    1, 4, false),  -- game 7
  ('Matthew Noble',     3, 'Ipswich Town',         'Liverpool',            1, 4, true ),  -- game 16
  ('Matthew Noble',     3, 'Newcastle United',     'AFC Bournemouth',      2, 2, false),  -- game 17
  ('Matthew Noble',     3, 'Brentford',            'Sunderland',           3, 1, false),  -- game 18
  ('Matthew Noble',     3, 'Brighton Hove Albion', 'Leeds United',         2, 1, false),  -- game 19
  ('Matthew Noble',     3, 'Fulham',               'Crystal Palace',       2, 1, false),  -- game 20
  ('Matthew Noble',     3, 'Manchester City',      'Coventry City',        4, 0, false),  -- game 21
  ('Matthew Noble',     3, 'Nottingham Forest',    'Tottenham Hotspur',    3, 2, false),  -- game 22
  ('Matthew Noble',     3, 'Hull City',            'Aston Villa',          1, 1, false),  -- game 23
  ('Matthew Noble',     4, 'West Ham United',      'Wrexham',              3, 1, false),  -- game 24
  ('Matthew Noble',     4, 'Aston Villa',          'Nottingham Forest',    0, 1, false),  -- game 25
  ('Matthew Noble',     4, 'AFC Bournemouth',      'Brentford',            1, 1, false),  -- game 26
  ('Matthew Noble',     4, 'Chelsea',              'Hull City',            3, 1, true ),  -- game 27
  ('Matthew Noble',     4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('Matthew Noble',     4, 'Liverpool',            'Fulham',               3, 2, false),  -- game 29
  ('Matthew Noble',     4, 'Tottenham Hotspur',    'Everton',              2, 2, false),  -- game 30
  ('Matthew Noble',     4, 'Sunderland',           'Arsenal',              1, 2, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 28: Schar Wars (Oliver Banks) (47)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Oliver Banks',      1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Oliver Banks',      1, 'Birmingham City',      'Bristol City',         1, 1, false),  -- game 2
  ('Oliver Banks',      1, 'Hull City',            'Manchester United',    0, 3, false),  -- game 3
  ('Oliver Banks',      1, 'Everton',              'Crystal Palace',       2, 2, false),  -- game 4
  ('Oliver Banks',      1, 'Ipswich Town',         'Sunderland',           2, 1, false),  -- game 5
  ('Oliver Banks',      1, 'Nottingham Forest',    'Leeds United',         1, 0, false),  -- game 6
  ('Oliver Banks',      1, 'Brentford',            'Tottenham Hotspur',    1, 3, false),  -- game 7
  ('Oliver Banks',      2, 'Crystal Palace',       'Manchester City',      2, 2, false),  -- game 8
  ('Oliver Banks',      2, 'Wrexham',              'Birmingham City',      3, 1, false),  -- game 9
  ('Oliver Banks',      2, 'Middlesbrough',        'West Bromwich Albion', 3, 1, false),  -- game 10
  ('Oliver Banks',      2, 'Liverpool',            'Nottingham Forest',    3, 2, false),  -- game 11
  ('Oliver Banks',      2, 'AFC Bournemouth',      'Everton',              2, 2, false),  -- game 12
  ('Oliver Banks',      2, 'Coventry City',        'Hull City',            3, 0, false),  -- game 13
  ('Oliver Banks',      2, 'Tottenham Hotspur',    'Newcastle United',     1, 3, true ),  -- game 14
  ('Oliver Banks',      2, 'Watford',              'West Ham United',      1, 3, false),  -- game 15
  ('Oliver Banks',      3, 'Ipswich Town',         'Liverpool',            0, 3, false),  -- game 16
  ('Oliver Banks',      3, 'Newcastle United',     'AFC Bournemouth',      2, 0, true ),  -- game 17
  ('Oliver Banks',      3, 'Brentford',            'Sunderland',           2, 1, false),  -- game 18
  ('Oliver Banks',      3, 'Brighton Hove Albion', 'Leeds United',         1, 0, false),  -- game 19
  ('Oliver Banks',      3, 'Fulham',               'Crystal Palace',       1, 0, false),  -- game 20
  ('Oliver Banks',      3, 'Manchester City',      'Coventry City',        3, 0, false),  -- game 21
  ('Oliver Banks',      3, 'Nottingham Forest',    'Tottenham Hotspur',    0, 1, false),  -- game 22
  ('Oliver Banks',      3, 'Hull City',            'Aston Villa',          1, 3, false),  -- game 23
  ('Oliver Banks',      4, 'West Ham United',      'Wrexham',              0, 2, false),  -- game 24
  ('Oliver Banks',      4, 'Aston Villa',          'Nottingham Forest',    2, 1, true ),  -- game 25
  ('Oliver Banks',      4, 'AFC Bournemouth',      'Brentford',            2, 1, false),  -- game 26
  ('Oliver Banks',      4, 'Chelsea',              'Hull City',            3, 2, false),  -- game 27
  ('Oliver Banks',      4, 'Crystal Palace',       'Ipswich Town',         1, 0, false),  -- game 28
  ('Oliver Banks',      4, 'Liverpool',            'Fulham',               3, 1, false),  -- game 29
  ('Oliver Banks',      4, 'Tottenham Hotspur',    'Everton',              3, 3, false),  -- game 30
  ('Oliver Banks',      4, 'Sunderland',           'Arsenal',              1, 4, false),  -- game 31
  ('Oliver Banks',      5, 'Brentford',            'Chelsea',              0, 3, true ),  -- game 32
  ('Oliver Banks',      5, 'Bristol City',         'Watford',              0, 2, false),  -- game 33
  ('Oliver Banks',      5, 'Tottenham Hotspur',    'Aston Villa',          2, 2, false),  -- game 34
  ('Oliver Banks',      5, 'Brighton Hove Albion', 'Arsenal',              1, 3, false),  -- game 35
  ('Oliver Banks',      5, 'Everton',              'Ipswich Town',         1, 0, false),  -- game 36
  ('Oliver Banks',      5, 'Millwall',             'West Ham United',      0, 2, false),  -- game 37
  ('Oliver Banks',      5, 'Wrexham',              'Southampton',          2, 0, false),  -- game 38
  ('Oliver Banks',      5, 'Newcastle United',     'Hull City',            2, 0, false),  -- game 39
  ('Oliver Banks',      5, 'Nottingham Forest',    'Coventry City',        2, 0, false),  -- game 40
  ('Oliver Banks',      6, 'Georgia',              'Northern Ireland',     1, 0, false),  -- game 41
  ('Oliver Banks',      6, 'Italy',                'Belgium',              2, 2, false),  -- game 42
  ('Oliver Banks',      6, 'Turkey',               'France',               0, 2, false),  -- game 43
  ('Oliver Banks',      6, 'Slovenia',             'Scotland',             0, 2, false),  -- game 44
  ('Oliver Banks',      6, 'San Marino',           'Finland',              0, 1, false),  -- game 45
  ('Oliver Banks',      6, 'Czech Republic',       'Croatia',              1, 2, false),  -- game 46
  ('Oliver Banks',      6, 'England',              'Spain',                1, 2, true )  -- game 47
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 29: SSC Napollie (Oliver Pocock) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Oliver Pocock',     1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Oliver Pocock',     1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Oliver Pocock',     1, 'Hull City',            'Manchester United',    1, 0, false),  -- game 3
  ('Oliver Pocock',     1, 'Everton',              'Crystal Palace',       1, 1, false),  -- game 4
  ('Oliver Pocock',     1, 'Ipswich Town',         'Sunderland',           2, 1, false),  -- game 5
  ('Oliver Pocock',     1, 'Nottingham Forest',    'Leeds United',         1, 2, false),  -- game 6
  ('Oliver Pocock',     1, 'Brentford',            'Tottenham Hotspur',    1, 3, false),  -- game 7
  ('Oliver Pocock',     2, 'Crystal Palace',       'Manchester City',      1, 2, false),  -- game 8
  ('Oliver Pocock',     2, 'Wrexham',              'Birmingham City',      3, 1, false),  -- game 9
  ('Oliver Pocock',     2, 'Middlesbrough',        'West Bromwich Albion', 2, 0, false),  -- game 10
  ('Oliver Pocock',     2, 'Liverpool',            'Nottingham Forest',    3, 1, true ),  -- game 11
  ('Oliver Pocock',     2, 'AFC Bournemouth',      'Everton',              2, 2, false),  -- game 12
  ('Oliver Pocock',     2, 'Coventry City',        'Hull City',            1, 1, false),  -- game 13
  ('Oliver Pocock',     2, 'Tottenham Hotspur',    'Newcastle United',     1, 3, false),  -- game 14
  ('Oliver Pocock',     2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Oliver Pocock',     3, 'Ipswich Town',         'Liverpool',            1, 2, false),  -- game 16
  ('Oliver Pocock',     3, 'Newcastle United',     'AFC Bournemouth',      3, 1, false),  -- game 17
  ('Oliver Pocock',     3, 'Brentford',            'Sunderland',           2, 1, false),  -- game 18
  ('Oliver Pocock',     3, 'Brighton Hove Albion', 'Leeds United',         2, 2, false),  -- game 19
  ('Oliver Pocock',     3, 'Fulham',               'Crystal Palace',       0, 2, false),  -- game 20
  ('Oliver Pocock',     3, 'Manchester City',      'Coventry City',        2, 0, true ),  -- game 21
  ('Oliver Pocock',     3, 'Nottingham Forest',    'Tottenham Hotspur',    2, 1, false),  -- game 22
  ('Oliver Pocock',     3, 'Hull City',            'Aston Villa',          1, 1, false),  -- game 23
  ('Oliver Pocock',     4, 'West Ham United',      'Wrexham',              2, 1, false),  -- game 24
  ('Oliver Pocock',     4, 'Aston Villa',          'Nottingham Forest',    1, 1, false),  -- game 25
  ('Oliver Pocock',     4, 'AFC Bournemouth',      'Brentford',            1, 2, false),  -- game 26
  ('Oliver Pocock',     4, 'Chelsea',              'Hull City',            3, 1, false),  -- game 27
  ('Oliver Pocock',     4, 'Crystal Palace',       'Ipswich Town',         2, 1, false),  -- game 28
  ('Oliver Pocock',     4, 'Liverpool',            'Fulham',               2, 0, false),  -- game 29
  ('Oliver Pocock',     4, 'Tottenham Hotspur',    'Everton',              0, 2, false),  -- game 30
  ('Oliver Pocock',     4, 'Sunderland',           'Arsenal',              1, 3, true )  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 30: Romans Rascals (Simon McNicholas) (39)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Simon McNicholas',  1, 'Arsenal',              'Coventry City',        2, 0, false),  -- game 1
  ('Simon McNicholas',  1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('Simon McNicholas',  1, 'Hull City',            'Manchester United',    1, 1, false),  -- game 3
  ('Simon McNicholas',  1, 'Everton',              'Crystal Palace',       1, 2, false),  -- game 4
  ('Simon McNicholas',  1, 'Ipswich Town',         'Sunderland',           3, 0, false),  -- game 5
  ('Simon McNicholas',  1, 'Nottingham Forest',    'Leeds United',         2, 2, true ),  -- game 6
  ('Simon McNicholas',  1, 'Brentford',            'Tottenham Hotspur',    1, 3, false),  -- game 7
  ('Simon McNicholas',  2, 'Crystal Palace',       'Manchester City',      1, 2, false),  -- game 8
  ('Simon McNicholas',  2, 'Wrexham',              'Birmingham City',      1, 1, true ),  -- game 9
  ('Simon McNicholas',  2, 'Middlesbrough',        'West Bromwich Albion', 0, 2, false),  -- game 10
  ('Simon McNicholas',  2, 'Liverpool',            'Nottingham Forest',    2, 1, false),  -- game 11
  ('Simon McNicholas',  2, 'AFC Bournemouth',      'Everton',              1, 0, false),  -- game 12
  ('Simon McNicholas',  2, 'Coventry City',        'Hull City',            0, 2, false),  -- game 13
  ('Simon McNicholas',  2, 'Tottenham Hotspur',    'Newcastle United',     1, 2, false),  -- game 14
  ('Simon McNicholas',  2, 'Watford',              'West Ham United',      2, 1, false),  -- game 15
  ('Simon McNicholas',  4, 'West Ham United',      'Wrexham',              2, 1, true ),  -- game 24
  ('Simon McNicholas',  4, 'Aston Villa',          'Nottingham Forest',    1, 1, false),  -- game 25
  ('Simon McNicholas',  4, 'AFC Bournemouth',      'Brentford',            1, 2, false),  -- game 26
  ('Simon McNicholas',  4, 'Chelsea',              'Hull City',            2, 2, false),  -- game 27
  ('Simon McNicholas',  4, 'Crystal Palace',       'Ipswich Town',         3, 0, false),  -- game 28
  ('Simon McNicholas',  4, 'Liverpool',            'Fulham',               1, 1, false),  -- game 29
  ('Simon McNicholas',  4, 'Tottenham Hotspur',    'Everton',              0, 2, false),  -- game 30
  ('Simon McNicholas',  4, 'Sunderland',           'Arsenal',              1, 3, false),  -- game 31
  ('Simon McNicholas',  5, 'Brentford',            'Chelsea',              2, 1, false),  -- game 32
  ('Simon McNicholas',  5, 'Bristol City',         'Watford',              1, 1, false),  -- game 33
  ('Simon McNicholas',  5, 'Tottenham Hotspur',    'Aston Villa',          1, 2, false),  -- game 34
  ('Simon McNicholas',  5, 'Brighton Hove Albion', 'Arsenal',              0, 2, false),  -- game 35
  ('Simon McNicholas',  5, 'Everton',              'Ipswich Town',         1, 1, false),  -- game 36
  ('Simon McNicholas',  5, 'Millwall',             'West Ham United',      2, 3, false),  -- game 37
  ('Simon McNicholas',  5, 'Wrexham',              'Southampton',          1, 1, false),  -- game 38
  ('Simon McNicholas',  5, 'Newcastle United',     'Hull City',            2, 1, false),  -- game 39
  ('Simon McNicholas',  5, 'Nottingham Forest',    'Coventry City',        1, 1, true ),  -- game 40
  ('Simon McNicholas',  6, 'Georgia',              'Northern Ireland',     1, 3, false),  -- game 41
  ('Simon McNicholas',  6, 'Italy',                'Belgium',              1, 2, false),  -- game 42
  ('Simon McNicholas',  6, 'Turkey',               'France',               1, 3, false),  -- game 43
  ('Simon McNicholas',  6, 'Slovenia',             'Scotland',             2, 0, false),  -- game 44
  ('Simon McNicholas',  6, 'San Marino',           'Finland',              1, 4, true ),  -- game 45
  ('Simon McNicholas',  6, 'Czech Republic',       'Croatia',              2, 2, false),  -- game 46
  ('Simon McNicholas',  6, 'England',              'Spain',                2, 1, false)  -- game 47
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 31: Geordie Goal Getters (Matthew Newton) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Matthew Newton',    1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Matthew Newton',    1, 'Birmingham City',      'Bristol City',         1, 1, false),  -- game 2
  ('Matthew Newton',    1, 'Hull City',            'Manchester United',    1, 2, false),  -- game 3
  ('Matthew Newton',    1, 'Everton',              'Crystal Palace',       1, 1, false),  -- game 4
  ('Matthew Newton',    1, 'Ipswich Town',         'Sunderland',           1, 1, false),  -- game 5
  ('Matthew Newton',    1, 'Nottingham Forest',    'Leeds United',         2, 1, false),  -- game 6
  ('Matthew Newton',    1, 'Brentford',            'Tottenham Hotspur',    1, 1, false),  -- game 7
  ('Matthew Newton',    2, 'Crystal Palace',       'Manchester City',      1, 3, false),  -- game 8
  ('Matthew Newton',    2, 'Wrexham',              'Birmingham City',      2, 0, false),  -- game 9
  ('Matthew Newton',    2, 'Middlesbrough',        'West Bromwich Albion', 2, 1, false),  -- game 10
  ('Matthew Newton',    2, 'Liverpool',            'Nottingham Forest',    1, 1, false),  -- game 11
  ('Matthew Newton',    2, 'AFC Bournemouth',      'Everton',              2, 2, false),  -- game 12
  ('Matthew Newton',    2, 'Coventry City',        'Hull City',            2, 1, false),  -- game 13
  ('Matthew Newton',    2, 'Tottenham Hotspur',    'Newcastle United',     0, 2, true ),  -- game 14
  ('Matthew Newton',    2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('Matthew Newton',    3, 'Ipswich Town',         'Liverpool',            1, 3, false),  -- game 16
  ('Matthew Newton',    3, 'Newcastle United',     'AFC Bournemouth',      3, 1, true ),  -- game 17
  ('Matthew Newton',    3, 'Brentford',            'Sunderland',           2, 0, false),  -- game 18
  ('Matthew Newton',    3, 'Brighton Hove Albion', 'Leeds United',         2, 1, false),  -- game 19
  ('Matthew Newton',    3, 'Fulham',               'Crystal Palace',       1, 2, false),  -- game 20
  ('Matthew Newton',    3, 'Manchester City',      'Coventry City',        3, 0, false),  -- game 21
  ('Matthew Newton',    3, 'Nottingham Forest',    'Tottenham Hotspur',    2, 1, false),  -- game 22
  ('Matthew Newton',    3, 'Hull City',            'Aston Villa',          1, 2, false),  -- game 23
  ('Matthew Newton',    4, 'West Ham United',      'Wrexham',              2, 1, false),  -- game 24
  ('Matthew Newton',    4, 'Aston Villa',          'Nottingham Forest',    1, 1, false),  -- game 25
  ('Matthew Newton',    4, 'AFC Bournemouth',      'Brentford',            2, 1, false),  -- game 26
  ('Matthew Newton',    4, 'Chelsea',              'Hull City',            3, 0, true ),  -- game 27
  ('Matthew Newton',    4, 'Crystal Palace',       'Ipswich Town',         2, 0, false),  -- game 28
  ('Matthew Newton',    4, 'Liverpool',            'Fulham',               2, 2, false),  -- game 29
  ('Matthew Newton',    4, 'Tottenham Hotspur',    'Everton',              0, 2, false),  -- game 30
  ('Matthew Newton',    4, 'Sunderland',           'Arsenal',              0, 3, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 32: Tricky Trees (James Seabury) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('James Seabury',     1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('James Seabury',     1, 'Birmingham City',      'Bristol City',         2, 1, false),  -- game 2
  ('James Seabury',     1, 'Hull City',            'Manchester United',    1, 2, false),  -- game 3
  ('James Seabury',     1, 'Everton',              'Crystal Palace',       2, 1, false),  -- game 4
  ('James Seabury',     1, 'Ipswich Town',         'Sunderland',           1, 1, false),  -- game 5
  ('James Seabury',     1, 'Nottingham Forest',    'Leeds United',         2, 2, false),  -- game 6
  ('James Seabury',     1, 'Brentford',            'Tottenham Hotspur',    1, 2, false),  -- game 7
  ('James Seabury',     2, 'Crystal Palace',       'Manchester City',      1, 3, true ),  -- game 8
  ('James Seabury',     2, 'Wrexham',              'Birmingham City',      1, 2, false),  -- game 9
  ('James Seabury',     2, 'Middlesbrough',        'West Bromwich Albion', 2, 1, false),  -- game 10
  ('James Seabury',     2, 'Liverpool',            'Nottingham Forest',    3, 1, false),  -- game 11
  ('James Seabury',     2, 'AFC Bournemouth',      'Everton',              2, 2, false),  -- game 12
  ('James Seabury',     2, 'Coventry City',        'Hull City',            1, 1, false),  -- game 13
  ('James Seabury',     2, 'Tottenham Hotspur',    'Newcastle United',     2, 3, false),  -- game 14
  ('James Seabury',     2, 'Watford',              'West Ham United',      1, 2, false),  -- game 15
  ('James Seabury',     3, 'Ipswich Town',         'Liverpool',            1, 2, false),  -- game 16
  ('James Seabury',     3, 'Newcastle United',     'AFC Bournemouth',      2, 1, false),  -- game 17
  ('James Seabury',     3, 'Brentford',            'Sunderland',           1, 1, false),  -- game 18
  ('James Seabury',     3, 'Brighton Hove Albion', 'Leeds United',         2, 1, false),  -- game 19
  ('James Seabury',     3, 'Fulham',               'Crystal Palace',       2, 1, false),  -- game 20
  ('James Seabury',     3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('James Seabury',     3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 2, false),  -- game 22
  ('James Seabury',     3, 'Hull City',            'Aston Villa',          1, 2, false),  -- game 23
  ('James Seabury',     4, 'West Ham United',      'Wrexham',              2, 1, false),  -- game 24
  ('James Seabury',     4, 'Aston Villa',          'Nottingham Forest',    2, 1, false),  -- game 25
  ('James Seabury',     4, 'AFC Bournemouth',      'Brentford',            2, 1, false),  -- game 26
  ('James Seabury',     4, 'Chelsea',              'Hull City',            3, 1, false),  -- game 27
  ('James Seabury',     4, 'Crystal Palace',       'Ipswich Town',         1, 1, false),  -- game 28
  ('James Seabury',     4, 'Liverpool',            'Fulham',               2, 0, true ),  -- game 29
  ('James Seabury',     4, 'Tottenham Hotspur',    'Everton',              2, 1, false),  -- game 30
  ('James Seabury',     4, 'Sunderland',           'Arsenal',              1, 2, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 33: Blasterz (Aashique Ahmed) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Aashique Ahmed',    1, 'Arsenal',              'Coventry City',        2, 0, false),  -- game 1
  ('Aashique Ahmed',    1, 'Birmingham City',      'Bristol City',         1, 0, false),  -- game 2
  ('Aashique Ahmed',    1, 'Hull City',            'Manchester United',    0, 2, true ),  -- game 3
  ('Aashique Ahmed',    1, 'Everton',              'Crystal Palace',       1, 0, false),  -- game 4
  ('Aashique Ahmed',    1, 'Ipswich Town',         'Sunderland',           2, 1, false),  -- game 5
  ('Aashique Ahmed',    1, 'Nottingham Forest',    'Leeds United',         1, 0, false),  -- game 6
  ('Aashique Ahmed',    1, 'Brentford',            'Tottenham Hotspur',    1, 1, false),  -- game 7
  ('Aashique Ahmed',    2, 'Crystal Palace',       'Manchester City',      0, 3, true ),  -- game 8
  ('Aashique Ahmed',    2, 'Wrexham',              'Birmingham City',      1, 0, false),  -- game 9
  ('Aashique Ahmed',    2, 'Middlesbrough',        'West Bromwich Albion', 1, 0, false),  -- game 10
  ('Aashique Ahmed',    2, 'Liverpool',            'Nottingham Forest',    2, 0, false),  -- game 11
  ('Aashique Ahmed',    2, 'AFC Bournemouth',      'Everton',              1, 0, false),  -- game 12
  ('Aashique Ahmed',    2, 'Coventry City',        'Hull City',            1, 1, false),  -- game 13
  ('Aashique Ahmed',    2, 'Tottenham Hotspur',    'Newcastle United',     1, 2, false),  -- game 14
  ('Aashique Ahmed',    2, 'Watford',              'West Ham United',      1, 3, false),  -- game 15
  ('Aashique Ahmed',    3, 'Ipswich Town',         'Liverpool',            1, 3, false),  -- game 16
  ('Aashique Ahmed',    3, 'Newcastle United',     'AFC Bournemouth',      1, 0, false),  -- game 17
  ('Aashique Ahmed',    3, 'Brentford',            'Sunderland',           2, 1, false),  -- game 18
  ('Aashique Ahmed',    3, 'Brighton Hove Albion', 'Leeds United',         1, 0, false),  -- game 19
  ('Aashique Ahmed',    3, 'Fulham',               'Crystal Palace',       1, 0, false),  -- game 20
  ('Aashique Ahmed',    3, 'Manchester City',      'Coventry City',        3, 0, true ),  -- game 21
  ('Aashique Ahmed',    3, 'Nottingham Forest',    'Tottenham Hotspur',    1, 0, false),  -- game 22
  ('Aashique Ahmed',    3, 'Hull City',            'Aston Villa',          1, 1, false),  -- game 23
  ('Aashique Ahmed',    4, 'West Ham United',      'Wrexham',              1, 0, false),  -- game 24
  ('Aashique Ahmed',    4, 'Aston Villa',          'Nottingham Forest',    2, 1, false),  -- game 25
  ('Aashique Ahmed',    4, 'AFC Bournemouth',      'Brentford',            2, 2, false),  -- game 26
  ('Aashique Ahmed',    4, 'Chelsea',              'Hull City',            3, 1, true ),  -- game 27
  ('Aashique Ahmed',    4, 'Crystal Palace',       'Ipswich Town',         1, 0, false),  -- game 28
  ('Aashique Ahmed',    4, 'Liverpool',            'Fulham',               2, 1, false),  -- game 29
  ('Aashique Ahmed',    4, 'Tottenham Hotspur',    'Everton',              2, 1, false),  -- game 30
  ('Aashique Ahmed',    4, 'Sunderland',           'Arsenal',              0, 1, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- tab 34: Colly's Mags (Jordan Collington) (31)
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
insert into public.predictions (league_id, fixture_id, entrant_id, home_score, away_score, is_bonus)
select l.id, f.id, en.id, v.home_score, v.away_score, v.is_bonus
from league l
cross join (values
  ('Jordan Collington', 1, 'Arsenal',              'Coventry City',        3, 0, true ),  -- game 1
  ('Jordan Collington', 1, 'Birmingham City',      'Bristol City',         2, 0, false),  -- game 2
  ('Jordan Collington', 1, 'Hull City',            'Manchester United',    1, 3, false),  -- game 3
  ('Jordan Collington', 1, 'Everton',              'Crystal Palace',       2, 1, false),  -- game 4
  ('Jordan Collington', 1, 'Ipswich Town',         'Sunderland',           0, 2, false),  -- game 5
  ('Jordan Collington', 1, 'Nottingham Forest',    'Leeds United',         3, 1, false),  -- game 6
  ('Jordan Collington', 1, 'Brentford',            'Tottenham Hotspur',    0, 2, false),  -- game 7
  ('Jordan Collington', 2, 'Crystal Palace',       'Manchester City',      0, 2, false),  -- game 8
  ('Jordan Collington', 2, 'Wrexham',              'Birmingham City',      2, 1, false),  -- game 9
  ('Jordan Collington', 2, 'Middlesbrough',        'West Bromwich Albion', 0, 2, true ),  -- game 10
  ('Jordan Collington', 2, 'Liverpool',            'Nottingham Forest',    3, 0, false),  -- game 11
  ('Jordan Collington', 2, 'AFC Bournemouth',      'Everton',              2, 1, false),  -- game 12
  ('Jordan Collington', 2, 'Coventry City',        'Hull City',            1, 0, false),  -- game 13
  ('Jordan Collington', 2, 'Tottenham Hotspur',    'Newcastle United',     1, 3, false),  -- game 14
  ('Jordan Collington', 2, 'Watford',              'West Ham United',      2, 0, false),  -- game 15
  ('Jordan Collington', 3, 'Ipswich Town',         'Liverpool',            0, 3, true ),  -- game 16
  ('Jordan Collington', 3, 'Newcastle United',     'AFC Bournemouth',      2, 0, false),  -- game 17
  ('Jordan Collington', 3, 'Brentford',            'Sunderland',           3, 1, false),  -- game 18
  ('Jordan Collington', 3, 'Brighton Hove Albion', 'Leeds United',         1, 2, false),  -- game 19
  ('Jordan Collington', 3, 'Fulham',               'Crystal Palace',       2, 1, false),  -- game 20
  ('Jordan Collington', 3, 'Manchester City',      'Coventry City',        4, 0, false),  -- game 21
  ('Jordan Collington', 3, 'Nottingham Forest',    'Tottenham Hotspur',    2, 1, false),  -- game 22
  ('Jordan Collington', 3, 'Hull City',            'Aston Villa',          0, 2, false),  -- game 23
  ('Jordan Collington', 4, 'West Ham United',      'Wrexham',              3, 0, true ),  -- game 24
  ('Jordan Collington', 4, 'Aston Villa',          'Nottingham Forest',    0, 1, false),  -- game 25
  ('Jordan Collington', 4, 'AFC Bournemouth',      'Brentford',            2, 2, false),  -- game 26
  ('Jordan Collington', 4, 'Chelsea',              'Hull City',            3, 2, false),  -- game 27
  ('Jordan Collington', 4, 'Crystal Palace',       'Ipswich Town',         2, 0, false),  -- game 28
  ('Jordan Collington', 4, 'Liverpool',            'Fulham',               3, 1, false),  -- game 29
  ('Jordan Collington', 4, 'Tottenham Hotspur',    'Everton',              1, 2, false),  -- game 30
  ('Jordan Collington', 4, 'Sunderland',           'Arsenal',              0, 2, false)  -- game 31
) as v(full_name, gameweek, home_team, away_team, home_score, away_score, is_bonus)
join public.entrants en
  on en.league_id = l.id and lower(btrim(en.full_name)) = lower(btrim(v.full_name))
join public.fixtures f
  on f.league_id = l.id
 and f.gameweek  = v.gameweek
 and lower(btrim(f.home_team)) = lower(btrim(v.home_team))
 and lower(btrim(f.away_team)) = lower(btrim(v.away_team))
on conflict (fixture_id, entrant_id) do update
set home_score = excluded.home_score,
    away_score = excluded.away_score,
    is_bonus   = excluded.is_bonus;

-- ---------------------------------------------------------------------------
-- Check. Expect 33 entrants, 47 fixtures, 1192 predictions — and the
-- same three numbers if you run the whole script a second time.
-- ---------------------------------------------------------------------------
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
select (select count(*) from public.entrants    e where e.league_id = l.id) as entrants,
       (select count(*) from public.fixtures    f where f.league_id = l.id) as fixtures,
       (select count(*) from public.predictions p where p.league_id = l.id) as predictions
from league l;

-- ---------------------------------------------------------------------------
-- Per-entrant counts. This is the one that catches a statement that did not
-- run: anybody showing 0 (or fewer rows than the sheet has for them) did not
-- get their insert. Expected counts are in the comment above each insert.
-- ---------------------------------------------------------------------------
with league as (select '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid as id)
select e.full_name, e.team_name, count(p.id) as predictions
from league l
join public.entrants e on e.league_id = l.id
left join public.predictions p on p.entrant_id = e.id
group by e.full_name, e.team_name
order by predictions, e.full_name;
