/* ==========================================================================
   Scoring engine
   --------------------------------------------------------------------------
   Rules (defaults, all overridable per league in Settings):
     exact result ................  7
     goal difference correct .....  4   (and not exact)
     outcome correct .............  2   (and GD not correct)
     wrong .......................  -1
     one bonus fixture per gameweek doubles that fixture's points
   Hierarchy matters: exact ⊃ goal-difference ⊃ outcome. A correct goal
   difference always implies a correct outcome, so it is tested first.
   ========================================================================== */

export const DEFAULT_RULES = Object.freeze({
  exact: 7,
  gd: 4,
  outcome: 2,
  wrong: -1,
  bonusMultiplier: 2,
  bonusAppliesToNegatives: true, // a doubled miss costs double
  bonusPerWeek: 1,
});

export function normaliseRules(raw) {
  const r = { ...DEFAULT_RULES, ...(raw || {}) };
  for (const k of ["exact", "gd", "outcome", "wrong", "bonusMultiplier", "bonusPerWeek"]) {
    const n = Number(r[k]);
    r[k] = Number.isFinite(n) ? n : DEFAULT_RULES[k];
  }
  r.bonusAppliesToNegatives = !!r.bonusAppliesToNegatives;
  return r;
}

export const hasResult = (fx) =>
  !!fx && fx.home_score !== null && fx.home_score !== undefined &&
  fx.away_score !== null && fx.away_score !== undefined &&
  fx.home_score !== "" && fx.away_score !== "";

const sign = (n) => (n > 0 ? 1 : n < 0 ? -1 : 0);

/** Classify a prediction against a finished fixture. */
export function classify(pred, fx) {
  const ph = Number(pred.home_score), pa = Number(pred.away_score);
  const ah = Number(fx.home_score), aa = Number(fx.away_score);
  if (ph === ah && pa === aa) return "exact";
  if (ph - pa === ah - aa) return "gd";
  if (sign(ph - pa) === sign(ah - aa)) return "outcome";
  return "wrong";
}

/**
 * Points for a single prediction.
 * @returns {{kind:string, base:number, points:number, bonus:boolean}}
 */
export function scorePrediction(pred, fx, rules = DEFAULT_RULES) {
  if (!pred || !hasResult(fx)) return { kind: "pending", base: 0, points: 0, bonus: false };
  if (pred.home_score === null || pred.home_score === undefined || pred.home_score === "" ||
      pred.away_score === null || pred.away_score === undefined || pred.away_score === "") {
    return { kind: "none", base: 0, points: 0, bonus: false };
  }
  const kind = classify(pred, fx);
  const base = rules[kind === "exact" ? "exact" : kind];
  const bonus = !!pred.is_bonus;
  let points = base;
  if (bonus && (base >= 0 || rules.bonusAppliesToNegatives)) points = base * rules.bonusMultiplier;
  return { kind, base, points, bonus };
}

export const KIND_LABELS = {
  exact: "Exact score",
  gd: "Goal difference",
  outcome: "Outcome",
  wrong: "Wrong",
  none: "No prediction",
  pending: "Awaiting result",
};

/* --------------------------------------------------------------------------
   Aggregation
   -------------------------------------------------------------------------- */

const blankTally = () => ({
  points: 0, exact: 0, gd: 0, outcome: 0, wrong: 0,
  played: 0, missing: 0, bonusFixtureId: null, bonusPoints: 0,
});

/**
 * Per-gameweek, per-entrant tallies.
 * @returns {{
 *   gameweeks: number[],
 *   completedGameweeks: number[],
 *   byGw: Map<number, Map<string, object>>,
 *   cells: Map<string, object>   // `${fixtureId}|${entrantId}` -> score result
 * }}
 */
export function buildTallies({ fixtures = [], predictions = [], entrants = [], rules }) {
  const R = normaliseRules(rules);
  const fxById = new Map(fixtures.map((f) => [String(f.id), f]));
  const gameweeks = [...new Set(fixtures.map((f) => Number(f.gameweek)))].sort((a, b) => a - b);

  const byGw = new Map();
  for (const gw of gameweeks) {
    const m = new Map();
    for (const e of entrants) m.set(String(e.id), blankTally());
    byGw.set(gw, m);
  }

  const cells = new Map();
  for (const p of predictions) {
    const fx = fxById.get(String(p.fixture_id));
    if (!fx) continue;
    const gw = Number(fx.gameweek);
    const tallies = byGw.get(gw);
    if (!tallies) continue;
    const eid = String(p.entrant_id);
    if (!tallies.has(eid)) tallies.set(eid, blankTally());
    const t = tallies.get(eid);

    const res = scorePrediction(p, fx, R);
    cells.set(`${fx.id}|${eid}`, res);

    if (p.is_bonus) t.bonusFixtureId = String(p.fixture_id);
    if (res.kind === "pending" || res.kind === "none") continue;

    t.points += res.points;
    t[res.kind] += 1;
    t.played += 1;
    if (res.bonus) t.bonusPoints += res.points - res.base;
  }

  // entrants who submitted nothing for a played fixture
  const predKey = new Set(predictions.map((p) => `${p.fixture_id}|${p.entrant_id}`));
  for (const fx of fixtures) {
    if (!hasResult(fx)) continue;
    const tallies = byGw.get(Number(fx.gameweek));
    for (const e of entrants) {
      if (!predKey.has(`${fx.id}|${e.id}`)) {
        const t = tallies.get(String(e.id)) || blankTally();
        t.missing += 1;
        tallies.set(String(e.id), t);
      }
    }
  }

  const completedGameweeks = gameweeks.filter((gw) =>
    fixtures.some((f) => Number(f.gameweek) === gw && hasResult(f))
  );

  return { gameweeks, completedGameweeks, byGw, cells, rules: R };
}

/** Sort comparator: points ▸ exact hits ▸ goal-difference hits ▸ name. */
function compareRows(a, b) {
  return (
    b.points - a.points ||
    b.exact - a.exact ||
    b.gd - a.gd ||
    a.name.localeCompare(b.name)
  );
}

function rankRows(rows) {
  rows.sort(compareRows);
  let lastKey = null, lastRank = 0;
  rows.forEach((r, i) => {
    const key = `${r.points}|${r.exact}|${r.gd}`;
    if (key === lastKey) { r.rank = lastRank; r.tied = true; }
    else { r.rank = i + 1; lastRank = r.rank; lastKey = key; r.tied = false; }
  });
  // mark ties both ways
  rows.forEach((r) => { r.tied = rows.filter((o) => o.rank === r.rank).length > 1; });
  return rows;
}

/**
 * Cumulative standings up to and including `throughGw`.
 * Pass `null` for "all time".
 */
export function standings(tal, entrants, throughGw = null) {
  const gws = tal.gameweeks.filter((gw) => throughGw === null || gw <= throughGw);
  const rows = entrants.map((e) => {
    const eid = String(e.id);
    const row = {
      entrantId: eid, name: e.full_name, team: e.team_name, userId: e.user_id || null,
      points: 0, exact: 0, gd: 0, outcome: 0, wrong: 0, played: 0, missing: 0,
      bonusPoints: 0, weeks: 0, best: null, worst: null, perGw: {},
    };
    for (const gw of gws) {
      const t = tal.byGw.get(gw)?.get(eid);
      if (!t) continue;
      row.perGw[gw] = t.points;
      row.points += t.points;
      row.exact += t.exact; row.gd += t.gd; row.outcome += t.outcome; row.wrong += t.wrong;
      row.played += t.played; row.missing += t.missing; row.bonusPoints += t.bonusPoints;
      if (t.played > 0) {
        row.weeks += 1;
        if (row.best === null || t.points > row.best) row.best = t.points;
        if (row.worst === null || t.points < row.worst) row.worst = t.points;
      }
    }
    row.avg = row.weeks ? row.points / row.weeks : 0;
    row.hitRate = row.played ? (row.exact + row.gd + row.outcome) / row.played : 0;
    return row;
  });
  return rankRows(rows);
}

/** Standings for a single gameweek only (the weekly winners table). */
export function gameweekStandings(tal, entrants, gw) {
  const rows = entrants.map((e) => {
    const t = tal.byGw.get(gw)?.get(String(e.id)) || blankTally();
    return {
      entrantId: String(e.id), name: e.full_name, team: e.team_name, userId: e.user_id || null,
      points: t.points, exact: t.exact, gd: t.gd, outcome: t.outcome, wrong: t.wrong,
      played: t.played, missing: t.missing, bonusFixtureId: t.bonusFixtureId,
      bonusPoints: t.bonusPoints,
    };
  });
  return rankRows(rows);
}

/**
 * Full history: standings after each completed gameweek, with movement.
 * @returns {Array<{gw:number, rows:Array}>} oldest → newest
 */
export function history(tal, entrants) {
  const out = [];
  let prevRanks = null;
  for (const gw of tal.completedGameweeks) {
    const rows = standings(tal, entrants, gw).map((r) => ({ ...r }));
    for (const r of rows) {
      const prev = prevRanks?.get(r.entrantId) ?? null;
      r.prevRank = prev;
      r.movement = prev === null ? null : prev - r.rank;
    }
    prevRanks = new Map(rows.map((r) => [r.entrantId, r.rank]));
    out.push({ gw, rows });
  }
  return out;
}

/** Recent form for one entrant: last n gameweek classifications, newest last. */
export function formFor(tal, entrantId, n = 6) {
  const gws = tal.completedGameweeks.slice(-n);
  return gws.map((gw) => ({ gw, points: tal.byGw.get(gw)?.get(String(entrantId))?.points ?? 0 }));
}

/** Records & superlatives for the Stats page. */
export function records(tal, entrants) {
  const all = standings(tal, entrants, null);
  const byId = new Map(all.map((r) => [r.entrantId, r]));
  let bestWeek = null, worstWeek = null;
  const weekWins = new Map();

  for (const gw of tal.completedGameweeks) {
    const rows = gameweekStandings(tal, entrants, gw).filter((r) => r.played > 0);
    if (!rows.length) continue;
    const top = rows[0];
    for (const r of rows.filter((x) => x.rank === 1)) {
      weekWins.set(r.entrantId, (weekWins.get(r.entrantId) || 0) + 1);
    }
    if (!bestWeek || top.points > bestWeek.points) {
      bestWeek = { gw, points: top.points, name: top.name, entrantId: top.entrantId };
    }
    const bottom = rows[rows.length - 1];
    if (!worstWeek || bottom.points < worstWeek.points) {
      worstWeek = { gw, points: bottom.points, name: bottom.name, entrantId: bottom.entrantId };
    }
  }

  const mostExact = [...all].sort((a, b) => b.exact - a.exact)[0] || null;
  const mostWeekWins = [...weekWins.entries()].sort((a, b) => b[1] - a[1])[0] || null;
  const bestBonus = [...all].sort((a, b) => b.bonusPoints - a.bonusPoints)[0] || null;

  return {
    all, byId, bestWeek, worstWeek, weekWins,
    mostExact,
    mostWeekWins: mostWeekWins
      ? { name: byId.get(mostWeekWins[0])?.name || "—", wins: mostWeekWins[1], entrantId: mostWeekWins[0] }
      : null,
    bestBonus,
  };
}

/** Head-to-head between two entrants across completed gameweeks. */
export function headToHead(tal, entrants, aId, bId) {
  const weeks = [];
  let aWins = 0, bWins = 0, draws = 0;
  for (const gw of tal.completedGameweeks) {
    const a = tal.byGw.get(gw)?.get(String(aId))?.points ?? 0;
    const b = tal.byGw.get(gw)?.get(String(bId))?.points ?? 0;
    if (a > b) aWins++; else if (b > a) bWins++; else draws++;
    weeks.push({ gw, a, b });
  }
  return { weeks, aWins, bWins, draws };
}
