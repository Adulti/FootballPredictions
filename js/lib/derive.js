/* Cached derived data: tallies are recomputed only when league data changes. */
import { state } from "./store.js";
import { buildTallies, standings, history, records } from "./scoring.js";

let sig = null, cache = null;

function signature() {
  return [
    state.leagueId,
    state.entrants.length,
    state.fixtures.length,
    state.predictions.length,
    JSON.stringify(state.league?.rules || {}),
    // cheap content hash so edits (results, scores, bonus) invalidate too
    state.fixtures.reduce((a, f) => a + (f.home_score ?? -9) * 31 + (f.away_score ?? -9) * 7 + f.gameweek * 13, 0),
    state.predictions.reduce((a, p) => a + (Number(p.home_score) || 0) * 3 + (Number(p.away_score) || 0) * 5 + (p.is_bonus ? 11 : 0), 0),
  ].join("~");
}

export function derived() {
  const s = signature();
  if (s === sig && cache) return cache;
  const tal = buildTallies({
    fixtures: state.fixtures,
    predictions: state.predictions,
    entrants: state.entrants,
    rules: state.league?.rules,
  });
  cache = {
    tal,
    rules: tal.rules,
    table: standings(tal, state.entrants, null),
    hist: history(tal, state.entrants),
    recs: records(tal, state.entrants),
  };
  sig = s;
  return cache;
}

export function invalidate() { sig = null; cache = null; }

/** The entrant row that belongs to the signed-in user, if linked. */
export function myEntrant() {
  return state.entrants.find((e) => e.user_id && e.user_id === state.user?.id) || null;
}

/** Latest gameweek that has at least one result. */
export function latestCompletedGw() {
  const { tal } = derived();
  return tal.completedGameweeks.length ? tal.completedGameweeks[tal.completedGameweeks.length - 1] : null;
}

/** Next gameweek with fixtures but no results yet. */
export function nextOpenGw() {
  const { tal } = derived();
  const done = new Set(tal.completedGameweeks);
  return tal.gameweeks.find((gw) => !done.has(gw)) ?? null;
}

export const fixturesFor = (gw) =>
  state.fixtures
    .filter((f) => Number(f.gameweek) === Number(gw))
    .sort((a, b) => String(a.kickoff || "").localeCompare(String(b.kickoff || "")) || a.home_team.localeCompare(b.home_team));

export const predIndex = () => {
  const m = new Map();
  for (const p of state.predictions) m.set(`${p.fixture_id}|${p.entrant_id}`, p);
  return m;
};
