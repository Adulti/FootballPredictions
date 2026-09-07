/* ==========================================================================
   Store — one API, two backends.

   • "supabase" : real Postgres + auth, used when config.js has credentials.
   • "demo"     : localStorage, no account required. Lets the GitHub Pages
                  build be explored (and developed) with zero setup.
   ========================================================================== */

import { DEFAULT_RULES } from "./scoring.js";

const CFG = window.PREDICTOR_CONFIG || {};
const LS_KEY = "predictor:demo:v1";
const LS_PREFS = "predictor:prefs:v1";

export const uid = () =>
  (crypto.randomUUID ? crypto.randomUUID()
    : "id-" + Math.random().toString(36).slice(2) + Date.now().toString(36));

export const mode = CFG.SUPABASE_URL && CFG.SUPABASE_ANON_KEY ? "supabase" : "demo";
export const isDemo = mode === "demo";

/* ---------- tiny prefs (theme, last league) ---------- */
export const prefs = {
  read() { try { return JSON.parse(localStorage.getItem(LS_PREFS)) || {}; } catch { return {}; } },
  get(k, d = null) { const v = this.read()[k]; return v === undefined ? d : v; },
  set(k, v) { const p = this.read(); p[k] = v; localStorage.setItem(LS_PREFS, JSON.stringify(p)); },
};

/* ==========================================================================
   Demo backend
   ========================================================================== */

function blankDb() {
  return { users: [], session: null, leagues: [], members: [], entrants: [], fixtures: [], predictions: [] };
}

function readDb() {
  try {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return null;
    const db = JSON.parse(raw);
    return { ...blankDb(), ...db };
  } catch { return null; }
}
function writeDb(db) { localStorage.setItem(LS_KEY, JSON.stringify(db)); return db; }

/* --- deterministic pseudo-random so the seed looks the same every time --- */
function rng(seed) {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

const CLUBS = [
  "Arsenal", "Aston Villa", "Bournemouth", "Brentford", "Brighton", "Chelsea",
  "Crystal Palace", "Everton", "Fulham", "Leeds", "Liverpool", "Man City",
  "Man Utd", "Newcastle", "Nott'm Forest", "Spurs", "West Ham", "Wolves",
];

const DEMO_PEOPLE = [
  ["Harry Adkins", "Adkins Athletic"],
  ["Priya Raman", "Raman Rovers"],
  ["Tom Beckett", "Beckett's Bunch"],
  ["Chloe Nkemelu", "Nkemelu FC"],
  ["Dan Whitlock", "Whitlock Wanderers"],
  ["Sofia Marín", "Marín United"],
  ["Owen Pritchard", "Pritchard Park"],
  ["Amara Osei", "Osei Olympic"],
];

function seedDemo(userId) {
  const db = blankDb();
  db.users.push({ id: userId, email: "demo@local", display_name: "Demo Admin" });
  db.session = userId;

  const now = Date.now();
  const day = 86400000;

  const mk = (name, season, weeksDone, entrantCount, seed, startWeeksAgo) => {
    const league = {
      id: uid(), name, season, owner_id: userId,
      join_code: name.replace(/[^A-Za-z]/g, "").slice(0, 4).toUpperCase() + String(1000 + Math.floor(seed % 9000)),
      rules: { ...DEFAULT_RULES }, created_at: new Date(now - startWeeksAgo * 7 * day).toISOString(),
    };
    db.leagues.push(league);
    db.members.push({ id: uid(), league_id: league.id, user_id: userId, role: "admin", created_at: league.created_at });

    const people = DEMO_PEOPLE.slice(0, entrantCount);
    const entrants = people.map(([full_name, team_name], i) => {
      const e = {
        id: uid(), league_id: league.id, full_name, team_name,
        user_id: i === 0 ? userId : null, created_at: league.created_at,
      };
      db.entrants.push(e); return e;
    });

    const r = rng(seed);
    const totalWeeks = weeksDone + 1; // one upcoming week with no results
    for (let gw = 1; gw <= totalWeeks; gw++) {
      const pool = [...CLUBS].sort(() => r() - 0.5);
      const kickoff = new Date(now - (startWeeksAgo - gw) * 7 * day + 2 * day).toISOString();
      const fixtures = [];
      for (let i = 0; i < 10; i += 2) {
        const done = gw <= weeksDone;
        const hs = Math.floor(r() * r() * 5), as = Math.floor(r() * r() * 4);
        const fx = {
          id: uid(), league_id: league.id, gameweek: gw,
          home_team: pool[i], away_team: pool[i + 1], kickoff,
          home_score: done ? hs : null, away_score: done ? as : null,
        };
        db.fixtures.push(fx); fixtures.push(fx);
      }
      for (const e of entrants) {
        const bonusIdx = Math.floor(r() * fixtures.length);
        fixtures.forEach((fx, idx) => {
          if (r() < 0.04) return; // occasional missing prediction
          // bias predictions toward the real result so scores look plausible
          const near = (actual) => {
            if (actual === null) return Math.floor(r() * r() * 4);
            const roll = r();
            if (roll < 0.42) return actual;
            return Math.max(0, actual + (r() < 0.5 ? -1 : 1));
          };
          db.predictions.push({
            id: uid(), league_id: league.id, fixture_id: fx.id, entrant_id: e.id,
            home_score: near(fx.home_score), away_score: near(fx.away_score),
            is_bonus: idx === bonusIdx,
          });
        });
      }
    }
    return league;
  };

  mk("Premier Predictions", "2025/26", 5, 8, 20260907, 6);
  mk("Office Cup", "2025/26", 2, 6, 771131, 3);
  return writeDb(db);
}

function ensureDemoDb() {
  let db = readDb();
  if (!db) db = seedDemo(uid());
  return db;
}

const clone = (o) => JSON.parse(JSON.stringify(o));

const demoBackend = {
  async currentUser() {
    const db = ensureDemoDb();
    if (!db.session) return null;
    const u = db.users.find((x) => x.id === db.session);
    return u ? { id: u.id, email: u.email, name: u.display_name } : null;
  },
  async signInDemo(name) {
    const db = ensureDemoDb();
    let u = db.users.find((x) => x.id === db.session) || db.users[0];
    if (!u) { u = { id: uid(), email: "demo@local", display_name: name || "Demo Admin" }; db.users.push(u); }
    if (name) u.display_name = name;
    db.session = u.id; writeDb(db);
    return { id: u.id, email: u.email, name: u.display_name };
  },
  async signIn() { return this.signInDemo(); },
  async signUp(_e, _p, name) { return this.signInDemo(name); },
  async signOut() { const db = ensureDemoDb(); db.session = null; writeDb(db); },

  async listLeagues(userId) {
    const db = ensureDemoDb();
    const mine = db.members.filter((m) => m.user_id === userId).map((m) => m.league_id);
    return db.leagues
      .filter((l) => mine.includes(l.id))
      .map((l) => ({ ...clone(l), role: db.members.find((m) => m.league_id === l.id && m.user_id === userId).role }))
      .sort((a, b) => a.name.localeCompare(b.name));
  },
  async createLeague({ name, season, rules }, userId) {
    const db = ensureDemoDb();
    const l = {
      id: uid(), name, season: season || "", owner_id: userId,
      join_code: makeJoinCode(), rules: rules || { ...DEFAULT_RULES },
      created_at: new Date().toISOString(),
    };
    db.leagues.push(l);
    db.members.push({ id: uid(), league_id: l.id, user_id: userId, role: "admin", created_at: l.created_at });
    writeDb(db);
    return { ...clone(l), role: "admin" };
  },
  async updateLeague(id, patch) {
    const db = ensureDemoDb();
    const l = db.leagues.find((x) => x.id === id);
    Object.assign(l, patch); writeDb(db); return clone(l);
  },
  async deleteLeague(id) {
    const db = ensureDemoDb();
    for (const t of ["leagues", "members", "entrants", "fixtures", "predictions"]) {
      db[t] = db[t].filter((r) => (t === "leagues" ? r.id !== id : r.league_id !== id));
    }
    writeDb(db);
  },
  async joinLeague(code, userId) {
    const db = ensureDemoDb();
    const l = db.leagues.find((x) => (x.join_code || "").toUpperCase() === code.trim().toUpperCase());
    if (!l) throw new Error("No league found with that code.");
    if (!db.members.some((m) => m.league_id === l.id && m.user_id === userId)) {
      db.members.push({ id: uid(), league_id: l.id, user_id: userId, role: "viewer", created_at: new Date().toISOString() });
      writeDb(db);
    }
    return clone(l);
  },
  async loadLeague(leagueId) {
    const db = ensureDemoDb();
    const pick = (t) => clone(db[t].filter((r) => r.league_id === leagueId));
    const members = pick("members").map((m) => ({
      ...m, display_name: db.users.find((u) => u.id === m.user_id)?.display_name || "Member",
      email: db.users.find((u) => u.id === m.user_id)?.email || "",
    }));
    return {
      entrants: pick("entrants").sort((a, b) => a.full_name.localeCompare(b.full_name)),
      fixtures: pick("fixtures"),
      predictions: pick("predictions"),
      members,
    };
  },
  async insert(table, rows) {
    const db = ensureDemoDb();
    const made = rows.map((r) => ({ id: uid(), created_at: new Date().toISOString(), ...r }));
    db[table].push(...made); writeDb(db); return clone(made);
  },
  async update(table, id, patch) {
    const db = ensureDemoDb();
    const row = db[table].find((r) => r.id === id);
    if (!row) throw new Error("Row not found");
    Object.assign(row, patch); writeDb(db); return clone(row);
  },
  async remove(table, ids) {
    const db = ensureDemoDb();
    const set = new Set(ids);
    db[table] = db[table].filter((r) => !set.has(r.id));
    if (table === "fixtures") db.predictions = db.predictions.filter((p) => !set.has(p.fixture_id));
    if (table === "entrants") db.predictions = db.predictions.filter((p) => !set.has(p.entrant_id));
    writeDb(db);
  },
  async upsertPredictions(rows) {
    const db = ensureDemoDb();
    for (const r of rows) {
      const found = db.predictions.find((p) => p.fixture_id === r.fixture_id && p.entrant_id === r.entrant_id);
      if (found) Object.assign(found, r);
      else db.predictions.push({ id: uid(), ...r });
    }
    writeDb(db); return rows.length;
  },
  async clearBonus(leagueId, entrantId, fixtureIds) {
    const db = ensureDemoDb();
    for (const p of db.predictions) {
      if (p.league_id === leagueId && p.entrant_id === entrantId && fixtureIds.includes(p.fixture_id)) p.is_bonus = false;
    }
    writeDb(db);
  },
  resetDemo() { localStorage.removeItem(LS_KEY); },
  reseedDemo() { localStorage.removeItem(LS_KEY); seedDemo(uid()); },
};

/* ==========================================================================
   Supabase backend
   ========================================================================== */

let sb = null;
async function client() {
  if (sb) return sb;
  const { createClient } = await import("https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm");
  sb = createClient(CFG.SUPABASE_URL, CFG.SUPABASE_ANON_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
  });
  return sb;
}
const ok = ({ data, error }) => { if (error) throw new Error(error.message); return data; };

const sbBackend = {
  async currentUser() {
    const c = await client();
    const { data } = await c.auth.getUser();
    const u = data?.user;
    if (!u) return null;
    return { id: u.id, email: u.email, name: u.user_metadata?.display_name || u.email?.split("@")[0] || "Player" };
  },
  async signIn(email, password) {
    const c = await client();
    ok(await c.auth.signInWithPassword({ email, password }));
    return this.currentUser();
  },
  async signUp(email, password, name) {
    const c = await client();
    const data = ok(await c.auth.signUp({ email, password, options: { data: { display_name: name } } }));
    if (!data.session) throw new Error("CONFIRM_EMAIL");
    return this.currentUser();
  },
  async signOut() { const c = await client(); await c.auth.signOut(); },

  async listLeagues() {
    const c = await client();
    const rows = ok(await c.from("league_members").select("role, leagues:league_id (*)"));
    return (rows || [])
      .filter((r) => r.leagues)
      .map((r) => ({ ...r.leagues, role: r.role }))
      .sort((a, b) => a.name.localeCompare(b.name));
  },
  async createLeague({ name, season, rules }, userId) {
    const c = await client();
    const league = ok(await c.from("leagues").insert({
      name, season: season || "", owner_id: userId,
      join_code: makeJoinCode(), rules: rules || { ...DEFAULT_RULES },
    }).select().single());
    ok(await c.from("league_members").insert({ league_id: league.id, user_id: userId, role: "admin" }));
    return { ...league, role: "admin" };
  },
  async updateLeague(id, patch) {
    const c = await client();
    return ok(await c.from("leagues").update(patch).eq("id", id).select().single());
  },
  async deleteLeague(id) {
    const c = await client();
    ok(await c.from("leagues").delete().eq("id", id));
  },
  async joinLeague(code) {
    const c = await client();
    // Privileged RPC: a non-member can't SELECT the league yet (see schema.sql).
    const league = ok(await c.rpc("join_league_by_code", { code: code.trim() }));
    if (!league) throw new Error("No league found with that code.");
    return league;
  },
  async loadLeague(leagueId) {
    const c = await client();
    const [entrants, fixtures, predictions, members] = await Promise.all([
      c.from("entrants").select("*").eq("league_id", leagueId).order("full_name"),
      c.from("fixtures").select("*").eq("league_id", leagueId).order("gameweek").order("kickoff", { nullsFirst: true }),
      c.from("predictions").select("*").eq("league_id", leagueId),
      c.from("league_members").select("*, profiles:user_id (display_name, email)").eq("league_id", leagueId),
    ]);
    return {
      entrants: ok(entrants) || [],
      fixtures: ok(fixtures) || [],
      predictions: ok(predictions) || [],
      members: (ok(members) || []).map((m) => ({
        ...m, display_name: m.profiles?.display_name || "Member", email: m.profiles?.email || "",
      })),
    };
  },
  async insert(table, rows) {
    const c = await client();
    return ok(await c.from(table).insert(rows).select());
  },
  async update(table, id, patch) {
    const c = await client();
    return ok(await c.from(table).update(patch).eq("id", id).select().single());
  },
  async remove(table, ids) {
    const c = await client();
    ok(await c.from(table).delete().in("id", ids));
  },
  async upsertPredictions(rows) {
    const c = await client();
    ok(await c.from("predictions").upsert(rows, { onConflict: "fixture_id,entrant_id" }));
    return rows.length;
  },
  async clearBonus(leagueId, entrantId, fixtureIds) {
    const c = await client();
    ok(await c.from("predictions").update({ is_bonus: false })
      .eq("league_id", leagueId).eq("entrant_id", entrantId).in("fixture_id", fixtureIds));
  },
};

export function makeJoinCode() {
  const A = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  return Array.from({ length: 6 }, () => A[Math.floor(Math.random() * A.length)]).join("");
}

const backend = isDemo ? demoBackend : sbBackend;
export { backend };

/* ==========================================================================
   App state
   ========================================================================== */

export const state = {
  user: null,
  leagues: [],
  leagueId: null,
  league: null,
  entrants: [], fixtures: [], predictions: [], members: [],
  loading: false,
};

export const isAdmin = () => !!state.league && (state.league.role === "admin" || state.league.owner_id === state.user?.id);

export async function refreshUser() {
  state.user = await backend.currentUser();
  return state.user;
}

export async function refreshLeagues() {
  state.leagues = state.user ? await backend.listLeagues(state.user.id) : [];
  return state.leagues;
}

export async function selectLeague(id) {
  state.leagueId = id;
  state.league = state.leagues.find((l) => String(l.id) === String(id)) || null;
  if (id) prefs.set("leagueId", id);
  if (!state.league) { state.entrants = state.fixtures = state.predictions = state.members = []; return; }
  const d = await backend.loadLeague(id);
  state.entrants = d.entrants; state.fixtures = d.fixtures;
  state.predictions = d.predictions; state.members = d.members;
}

export async function reloadLeagueData() {
  if (state.leagueId) await selectLeague(state.leagueId);
}

/* ---------- entity helpers used by views ---------- */

export const api = {
  /* entrants */
  addEntrants: (rows) => backend.insert("entrants", rows.map((r) => ({ league_id: state.leagueId, ...r }))),
  updateEntrant: (id, patch) => backend.update("entrants", id, patch),
  deleteEntrants: (ids) => backend.remove("entrants", ids),

  /* fixtures */
  addFixtures: (rows) => backend.insert("fixtures", rows.map((r) => ({ league_id: state.leagueId, ...r }))),
  updateFixture: (id, patch) => backend.update("fixtures", id, patch),
  deleteFixtures: (ids) => backend.remove("fixtures", ids),

  /* predictions */
  savePredictions: (rows) => backend.upsertPredictions(rows.map((r) => ({ league_id: state.leagueId, ...r }))),
  clearBonus: (entrantId, fixtureIds) => backend.clearBonus(state.leagueId, entrantId, fixtureIds),
  deletePredictions: (ids) => backend.remove("predictions", ids),

  /* league */
  updateLeague: async (patch) => {
    const l = await backend.updateLeague(state.leagueId, patch);
    Object.assign(state.league, l);
    const idx = state.leagues.findIndex((x) => String(x.id) === String(state.leagueId));
    if (idx > -1) state.leagues[idx] = { ...state.leagues[idx], ...l };
    return l;
  },
  deleteLeague: (id) => backend.deleteLeague(id),
  createLeague: (payload) => backend.createLeague(payload, state.user.id),
  joinLeague: (code) => backend.joinLeague(code, state.user.id),

  /* members */
  setMemberRole: (id, role) => backend.update("league_members", id, { role }),
  removeMember: (id) => backend.remove("league_members", [id]),
};
