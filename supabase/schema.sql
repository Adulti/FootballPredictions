-- ===========================================================================
-- Predictor — Supabase / Postgres schema
-- ---------------------------------------------------------------------------
-- Run this once in the Supabase SQL editor (Dashboard → SQL → New query).
-- Safe to re-run: everything is created with "if not exists" / "or replace".
-- ===========================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- profiles — mirrors auth.users so member lists can show names
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text not null default 'Player',
  email         text,
  created_at    timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1), 'Player'),
    new.email
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- leagues
-- ---------------------------------------------------------------------------
create table if not exists public.leagues (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  season      text default '',
  owner_id    uuid not null references auth.users(id) on delete cascade,
  join_code   text unique,
  rules       jsonb not null default '{
    "exact": 7, "gd": 4, "outcome": 2, "wrong": -1,
    "bonusMultiplier": 2, "bonusAppliesToNegatives": true, "bonusPerWeek": 1
  }'::jsonb,
  created_at  timestamptz not null default now()
);

-- user_id points at profiles (not auth.users) so PostgREST can embed the
-- member's name in one request: select('*, profiles:user_id (display_name)').
-- profiles.id itself cascades from auth.users, so deletes still propagate.
create table if not exists public.league_members (
  id          uuid primary key default gen_random_uuid(),
  league_id   uuid not null references public.leagues(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  role        text not null default 'viewer' check (role in ('admin', 'viewer')),
  created_at  timestamptz not null default now(),
  unique (league_id, user_id)
);

create table if not exists public.entrants (
  id          uuid primary key default gen_random_uuid(),
  league_id   uuid not null references public.leagues(id) on delete cascade,
  full_name   text not null,
  team_name   text default '',
  user_id     uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);

create table if not exists public.fixtures (
  id          uuid primary key default gen_random_uuid(),
  league_id   uuid not null references public.leagues(id) on delete cascade,
  gameweek    int  not null default 1,
  home_team   text not null,
  away_team   text not null,
  kickoff     timestamptz,
  home_score  int check (home_score is null or home_score between 0 and 99),
  away_score  int check (away_score is null or away_score between 0 and 99),
  created_at  timestamptz not null default now()
);

create table if not exists public.predictions (
  id          uuid primary key default gen_random_uuid(),
  league_id   uuid not null references public.leagues(id) on delete cascade,
  fixture_id  uuid not null references public.fixtures(id) on delete cascade,
  entrant_id  uuid not null references public.entrants(id) on delete cascade,
  home_score  int not null check (home_score between 0 and 99),
  away_score  int not null check (away_score between 0 and 99),
  is_bonus    boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (fixture_id, entrant_id)
);

create index if not exists idx_members_user     on public.league_members(user_id);
create index if not exists idx_entrants_league  on public.entrants(league_id);
create index if not exists idx_fixtures_league  on public.fixtures(league_id, gameweek);
create index if not exists idx_preds_league     on public.predictions(league_id);
create index if not exists idx_preds_fixture    on public.predictions(fixture_id);
create index if not exists idx_preds_entrant    on public.predictions(entrant_id);

-- ---------------------------------------------------------------------------
-- helpers (security definer, so policies never recurse into league_members)
-- ---------------------------------------------------------------------------
create or replace function public.is_league_member(lid uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.league_members m
    where m.league_id = lid and m.user_id = auth.uid()
  ) or exists (
    select 1 from public.leagues l
    where l.id = lid and l.owner_id = auth.uid()
  );
$$;

create or replace function public.is_league_admin(lid uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists (
    select 1 from public.league_members m
    where m.league_id = lid and m.user_id = auth.uid() and m.role = 'admin'
  ) or exists (
    select 1 from public.leagues l
    where l.id = lid and l.owner_id = auth.uid()
  );
$$;

-- Joining by code needs to read a league the caller cannot yet see, so it is
-- done in one privileged function rather than by loosening the read policy.
create or replace function public.join_league_by_code(code text)
returns public.leagues language plpgsql security definer set search_path = public as $$
declare
  target public.leagues;
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  select * into target from public.leagues
  where upper(join_code) = upper(btrim(code))
  limit 1;

  if target.id is null then
    raise exception 'No league found with that code.';
  end if;

  -- league_members.user_id references profiles, so make sure one exists
  insert into public.profiles (id, display_name, email)
  select u.id,
         coalesce(u.raw_user_meta_data->>'display_name', split_part(u.email, '@', 1), 'Player'),
         u.email
  from auth.users u where u.id = auth.uid()
  on conflict (id) do nothing;

  insert into public.league_members (league_id, user_id, role)
  values (target.id, auth.uid(), 'viewer')
  on conflict (league_id, user_id) do nothing;

  return target;
end $$;

grant execute on function public.join_league_by_code(text) to authenticated;

-- ---------------------------------------------------------------------------
-- row level security
-- ---------------------------------------------------------------------------
alter table public.profiles       enable row level security;
alter table public.leagues        enable row level security;
alter table public.league_members enable row level security;
alter table public.entrants       enable row level security;
alter table public.fixtures       enable row level security;
alter table public.predictions    enable row level security;

-- profiles: readable by anyone signed in (member lists), writable by self
drop policy if exists profiles_read   on public.profiles;
drop policy if exists profiles_write  on public.profiles;
create policy profiles_read  on public.profiles for select to authenticated using (true);
create policy profiles_write on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- leagues
drop policy if exists leagues_read   on public.leagues;
drop policy if exists leagues_insert on public.leagues;
drop policy if exists leagues_update on public.leagues;
drop policy if exists leagues_delete on public.leagues;
create policy leagues_read   on public.leagues for select to authenticated
  using (owner_id = auth.uid() or public.is_league_member(id));
create policy leagues_insert on public.leagues for insert to authenticated
  with check (owner_id = auth.uid());
create policy leagues_update on public.leagues for update to authenticated
  using (public.is_league_admin(id)) with check (public.is_league_admin(id));
create policy leagues_delete on public.leagues for delete to authenticated
  using (owner_id = auth.uid());

-- league_members
drop policy if exists members_read   on public.league_members;
drop policy if exists members_insert on public.league_members;
drop policy if exists members_update on public.league_members;
drop policy if exists members_delete on public.league_members;
create policy members_read on public.league_members for select to authenticated
  using (user_id = auth.uid() or public.is_league_member(league_id));
create policy members_insert on public.league_members for insert to authenticated
  with check (user_id = auth.uid() or public.is_league_admin(league_id));
create policy members_update on public.league_members for update to authenticated
  using (public.is_league_admin(league_id)) with check (public.is_league_admin(league_id));
create policy members_delete on public.league_members for delete to authenticated
  using (user_id = auth.uid() or public.is_league_admin(league_id));

-- entrants / fixtures / predictions: every member reads, only admins write

drop policy if exists entrants_read   on public.entrants;
drop policy if exists entrants_insert on public.entrants;
drop policy if exists entrants_update on public.entrants;
drop policy if exists entrants_delete on public.entrants;
create policy entrants_read   on public.entrants for select to authenticated
  using (public.is_league_member(league_id));
create policy entrants_insert on public.entrants for insert to authenticated
  with check (public.is_league_admin(league_id));
create policy entrants_update on public.entrants for update to authenticated
  using (public.is_league_admin(league_id)) with check (public.is_league_admin(league_id));
create policy entrants_delete on public.entrants for delete to authenticated
  using (public.is_league_admin(league_id));

drop policy if exists fixtures_read   on public.fixtures;
drop policy if exists fixtures_insert on public.fixtures;
drop policy if exists fixtures_update on public.fixtures;
drop policy if exists fixtures_delete on public.fixtures;
create policy fixtures_read   on public.fixtures for select to authenticated
  using (public.is_league_member(league_id));
create policy fixtures_insert on public.fixtures for insert to authenticated
  with check (public.is_league_admin(league_id));
create policy fixtures_update on public.fixtures for update to authenticated
  using (public.is_league_admin(league_id)) with check (public.is_league_admin(league_id));
create policy fixtures_delete on public.fixtures for delete to authenticated
  using (public.is_league_admin(league_id));

drop policy if exists predictions_read   on public.predictions;
drop policy if exists predictions_insert on public.predictions;
drop policy if exists predictions_update on public.predictions;
drop policy if exists predictions_delete on public.predictions;
create policy predictions_read   on public.predictions for select to authenticated
  using (public.is_league_member(league_id));
create policy predictions_insert on public.predictions for insert to authenticated
  with check (public.is_league_admin(league_id));
create policy predictions_update on public.predictions for update to authenticated
  using (public.is_league_admin(league_id)) with check (public.is_league_admin(league_id));
create policy predictions_delete on public.predictions for delete to authenticated
  using (public.is_league_admin(league_id));

-- ---------------------------------------------------------------------------
-- Backfill profiles for users that existed before the trigger
-- ---------------------------------------------------------------------------
insert into public.profiles (id, display_name, email)
select u.id,
       coalesce(u.raw_user_meta_data->>'display_name', split_part(u.email, '@', 1), 'Player'),
       u.email
from auth.users u
on conflict (id) do nothing;
