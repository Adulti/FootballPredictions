-- ===========================================================================
-- Diagnostics for the LIVE SHEET import. Read-only: nothing here writes.
-- Run in the Supabase SQL editor and paste the output back.
-- Keyed to league id 7f5a9813-43fa-4c4e-a068-12bed7129fe2 (Banks Prediction League).
-- ===========================================================================

-- (A) THE IMPORTANT ONE — one person's full scoring input.
-- Jordan Collington shows -48. This lists every prediction he has, the fixture
-- it is attached to, and what js/lib/scoring.js would score it, so we can add
-- it up by hand and compare with what the app displays.
select e.full_name,
       e.team_name,
       f.gameweek,
       f.home_team, f.away_team,
       f.home_score || '-' || f.away_score as actual,
       p.home_score || '-' || p.away_score as predicted,
       p.is_bonus,
       case
         when f.home_score is null then 'pending'
         when p.home_score = f.home_score and p.away_score = f.away_score then 'exact 7'
         when p.home_score - p.away_score = f.home_score - f.away_score then 'gd 4'
         when sign(p.home_score - p.away_score) = sign(f.home_score - f.away_score) then 'outcome 2'
         else 'wrong -1'
       end as would_score
from public.entrants e
join public.leagues lg on lg.id = e.league_id and lg.id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid
left join public.predictions p on p.entrant_id = e.id
left join public.fixtures f on f.id = p.fixture_id
where lower(btrim(e.full_name)) = 'jordan collington'
order by e.id, f.gameweek, f.home_team;

-- (B) Predictions per FIXTURE. A fixture WITH a result but 0 predictions is one
-- every entrant is marked "no prediction" on.
select f.gameweek, f.home_team, f.away_team, f.home_score, f.away_score,
       (f.home_score is not null) as has_result,
       count(p.id) as predictions
from public.fixtures f
join public.leagues lg on lg.id = f.league_id and lg.id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid
left join public.predictions p on p.fixture_id = f.id
group by f.id, f.gameweek, f.home_team, f.away_team, f.home_score, f.away_score
order by has_result desc, predictions, f.gameweek, f.home_team;

-- (C) Predictions per ENTRANT, lowest first.
select e.full_name, '[' || coalesce(e.team_name,'<null>') || ']' as team, e.id,
       count(p.id) as predictions
from public.entrants e
join public.leagues lg on lg.id = e.league_id and lg.id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid
left join public.predictions p on p.entrant_id = e.id
group by e.full_name, e.team_name, e.id
order by predictions, e.full_name;

-- (D) Totals. The spreadsheet has 47 fixtures, 23 with results, 33 entrants.
select count(*) as fixtures,
       count(*) filter (where f.home_score is not null) as with_results,
       (select count(*) from public.entrants e where e.league_id = lg.id) as entrants,
       (select count(*) from public.predictions p where p.league_id = lg.id) as predictions
from public.fixtures f
join public.leagues lg on lg.id = f.league_id and lg.id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid
group by lg.id;

-- (E) Duplicate entrants (same person, different team spelling).
select lower(btrim(full_name)) as person, count(*) as copies,
       array_agg('[' || coalesce(team_name,'<null>') || ']') as team_names
from public.entrants e
join public.leagues lg on lg.id = e.league_id and lg.id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid
group by 1 having count(*) > 1;

-- (F) Duplicate fixtures (same match more than once).
select lower(btrim(home_team)) as home, lower(btrim(away_team)) as away,
       count(*) as copies, array_agg(gameweek order by gameweek) as gameweeks
from public.fixtures f
join public.leagues lg on lg.id = f.league_id and lg.id = '7f5a9813-43fa-4c4e-a068-12bed7129fe2'::uuid
group by 1,2 having count(*) > 1;

-- (G) The league's stored scoring rules, and how many leagues exist.
select id, name, season, rules from public.leagues;
