/* ==========================================================================
   App shell + hash router
   ========================================================================== */

import {
  state, isDemo, isAdmin, prefs, backend,
  refreshUser, refreshLeagues, selectLeague, reloadLeagueData, api,
} from "./lib/store.js";
import { invalidate, derived } from "./lib/derive.js";
import { qs, qsa, html, raw, icon, toast, closeModal, initials, on } from "./lib/ui.js";
import { parseHash, navigate } from "./lib/router.js";

import * as vDashboard from "./views/dashboard.js";
import * as vTable from "./views/table.js";
import * as vWeeks from "./views/weeks.js";
import * as vHistory from "./views/history.js";
import * as vFixtures from "./views/fixtures.js";
import * as vPredictions from "./views/predictions.js";
import * as vEntrants from "./views/entrants.js";
import * as vStats from "./views/stats.js";
import * as vSettings from "./views/settings.js";
import * as vLeagues from "./views/leagues.js";
import { renderAuth } from "./views/auth.js";

const ROUTES = {
  dashboard:   { view: vDashboard,   title: "Overview",        icon: "home",     group: "league" },
  table:       { view: vTable,       title: "League table",    icon: "trophy",   group: "league" },
  weeks:       { view: vWeeks,       title: "Weekly results",  icon: "calendar", group: "league" },
  history:     { view: vHistory,     title: "Table history",   icon: "history",  group: "league" },
  stats:       { view: vStats,       title: "Stats & records", icon: "chart",    group: "league" },
  fixtures:    { view: vFixtures,    title: "Fixtures",        icon: "clock",    group: "admin" },
  predictions: { view: vPredictions, title: "Predictions",     icon: "edit",     group: "admin" },
  entrants:    { view: vEntrants,    title: "Entrants",        icon: "users",    group: "admin" },
  settings:    { view: vSettings,    title: "Settings",        icon: "gear",     group: "admin" },
  leagues:     { view: vLeagues,     title: "My leagues",      icon: "swap",     group: null },
};

/* ---------- theme ---------- */
function applyTheme(t) {
  document.documentElement.dataset.theme = t === "system" ? "" : t;
  prefs.set("theme", t);
}
function cycleTheme() {
  const cur = prefs.get("theme", "system");
  const next = cur === "system" ? "light" : cur === "light" ? "dark" : "system";
  applyTheme(next);
  renderShellChrome();
  toast(`Theme: ${next}`);
}

/* ---------- render ---------- */
const appEl = () => qs("#app");

export async function rerender({ reload = false } = {}) {
  if (reload) { invalidate(); await reloadLeagueData(); }
  await render();
}

async function render() {
  const app = appEl();

  if (!state.user) { app.innerHTML = renderAuth(); wireAuth(app); reveal(); return; }

  if (!state.leagues.length) {
    app.innerHTML = shellHtml("leagues");
    await mountView("leagues");
    wireShell(app);
    reveal();
    return;
  }

  const { route } = parseHash();
  const def = ROUTES[route];
  if (def.group === "admin" && !isAdmin() && route !== "leagues") {
    navigate("dashboard");
    return;
  }

  app.innerHTML = shellHtml(route);
  wireShell(app);
  await mountView(route);
  reveal();
}

async function mountView(route) {
  const host = qs("#view");
  const def = ROUTES[route];
  host.innerHTML = `<div class="muted" style="padding:24px">Loading…</div>`;
  try {
    await def.view.render(host, { navigate, rerender });
  } catch (err) {
    console.error(err);
    host.innerHTML = html`<div class="card"><div class="card__body">
      <h3>Couldn't render this page</h3>
      <p class="muted" style="margin-top:6px">${err.message || String(err)}</p>
    </div></div>`;
  }
}

function reveal() {
  qs("#boot")?.remove();
  appEl().hidden = false;
}

/* ---------- shell markup ---------- */
function navLink(key, active) {
  const d = ROUTES[key];
  return html`<a class="nav__link ${key === active ? "is-active" : ""}" href="#/${key}">
    ${icon(d.icon)}<span>${d.title}</span>
  </a>`;
}

function shellHtml(active) {
  const admin = isAdmin();
  const L = state.league;
  const def = ROUTES[active];
  const theme = prefs.get("theme", "system");
  const themeIcon = theme === "dark" ? "moon" : theme === "light" ? "sun" : "zap";

  return html`
  <div class="shell">
    <aside class="sidebar">
      <div class="brand">
        <div class="brand__mark">🏆</div>
        <div class="brand__name">${window.PREDICTOR_CONFIG?.APP_NAME || "Predictor"}</div>
      </div>

      <div class="lgpicker">
        <button class="lgpicker__btn" id="lg-toggle" aria-haspopup="true" aria-expanded="false">
          <div class="avatar">${initials(L?.name || "?")}</div>
          <div class="lgpicker__meta">
            <span class="lgpicker__label">League</span>
            <span class="lgpicker__name">${L?.name || "Choose a league"}</span>
          </div>
          ${icon("chevronDown", 15)}
        </button>
        <div class="lgpicker__menu" id="lg-menu" hidden>
          ${raw(state.leagues.map((l) => html`
            <button class="lgpicker__item" data-league="${l.id}" aria-current="${String(l.id) === String(state.leagueId)}">
              <div class="avatar" style="width:22px;height:22px;font-size:9.5px">${initials(l.name)}</div>
              <span class="truncate">${l.name}</span>
              ${l.season ? html`<span class="pill" style="margin-left:auto">${l.season}</span>` : ""}
            </button>`).join(""))}
          <div class="lgpicker__sep"></div>
          <button class="lgpicker__item" data-goto="leagues">${icon("gear", 15)}<span>Manage leagues</span></button>
        </div>
      </div>

      <nav class="nav">
        <div class="nav__group">
          <div class="nav__title">League</div>
          ${raw(["dashboard", "table", "weeks", "history", "stats"].map((k) => navLink(k, active)).join(""))}
        </div>
        ${admin ? html`<div class="nav__group">
          <div class="nav__title">Admin</div>
          ${raw(["fixtures", "predictions", "entrants", "settings"].map((k) => navLink(k, active)).join(""))}
        </div>` : ""}
        <div class="nav__group">
          <div class="nav__title">Account</div>
          ${raw(navLink("leagues", active))}
        </div>
      </nav>

      <div class="sidebar__foot">
        ${isDemo ? html`<div class="pill pill--warn" title="No database configured — data lives in this browser only">
          ${icon("zap", 13)} Demo mode</div>` : ""}
        <div class="userchip">
          <div class="avatar">${initials(state.user?.name)}</div>
          <div class="userchip__meta">
            <span class="userchip__name">${state.user?.name || "Player"}</span>
            <span class="userchip__sub">${state.user?.email || ""}</span>
          </div>
        </div>
        <div class="row" style="gap:6px">
          <button class="btn btn--ghost btn--sm" id="theme-btn" title="Change theme">${icon(themeIcon, 15)} Theme</button>
          <button class="btn btn--ghost btn--sm" id="signout-btn" title="Sign out">${icon("logout", 15)} Sign out</button>
        </div>
      </div>
    </aside>

    <div class="main">
      <header class="topbar">
        <button class="btn btn--ghost btn--icon hamburger" id="nav-toggle" aria-label="Menu">${icon("menu")}</button>
        <div>
          <h1>${def.title}</h1>
          <div class="topbar__sub">${L ? `${L.name}${L.season ? ` · ${L.season}` : ""}` : ""}</div>
        </div>
        <div class="spacer"></div>
        ${admin ? html`<span class="pill pill--accent" title="You can edit this league">${icon("check", 13)} Admin</span>` : ""}
      </header>
      <main class="content" id="view"></main>
    </div>
  </div>`;
}

/* ---------- shell wiring ---------- */
function wireShell(root) {
  const toggle = qs("#lg-toggle", root);
  const menu = qs("#lg-menu", root);
  toggle?.addEventListener("click", (e) => {
    e.stopPropagation();
    const open = menu.hidden;
    menu.hidden = !open;
    toggle.setAttribute("aria-expanded", String(open));
  });
  document.addEventListener("click", () => { if (menu && !menu.hidden) { menu.hidden = true; toggle.setAttribute("aria-expanded", "false"); } }, { once: true });

  on(root, "click", "[data-league]", async (e, el) => {
    e.preventDefault();
    const id = el.dataset.league;
    if (String(id) === String(state.leagueId)) { menu.hidden = true; return; }
    invalidate();
    await selectLeague(id);
    await render();
    toast(`Switched to ${state.league.name}`, "good");
  });
  on(root, "click", "[data-goto]", (e, el) => { e.preventDefault(); navigate(el.dataset.goto); });

  qs("#theme-btn", root)?.addEventListener("click", cycleTheme);
  qs("#signout-btn", root)?.addEventListener("click", async () => {
    await backend.signOut();
    state.user = null; state.leagues = []; state.leagueId = null; state.league = null;
    invalidate();
    await render();
  });

  qs("#nav-toggle", root)?.addEventListener("click", () => document.body.classList.toggle("nav-open"));
  on(root, "click", ".nav__link", () => document.body.classList.remove("nav-open"));
}

function renderShellChrome() {
  const btn = qs("#theme-btn");
  if (!btn) return;
  const theme = prefs.get("theme", "system");
  const name = theme === "dark" ? "moon" : theme === "light" ? "sun" : "zap";
  btn.innerHTML = html`${icon(name, 15)} Theme`;
}

/* ---------- auth wiring ---------- */
function wireAuth(root) {
  if (!root.dataset.authMode) root.dataset.authMode = "signin";
  const form = qs("#auth-form", root);
  const err = qs("#auth-err", root);
  const showErr = (m) => { err.textContent = m; err.hidden = false; };

  qsa("[data-mode]", root).forEach((b) => b.addEventListener("click", () => {
    qsa("[data-mode]", root).forEach((x) => x.setAttribute("aria-selected", String(x === b)));
    root.dataset.authMode = b.dataset.mode;
    qs("#name-field", root).hidden = b.dataset.mode !== "signup";
    qs("#auth-submit", root).textContent = b.dataset.mode === "signup" ? "Create account" : "Sign in";
    err.hidden = true;
  }));

  qs("#demo-btn", root)?.addEventListener("click", async () => {
    await backend.signInDemo();
    await boot(true);
  });

  form?.addEventListener("submit", async (e) => {
    e.preventDefault();
    err.hidden = true;
    const btn = qs("#auth-submit", root);
    btn.disabled = true;
    const email = qs("#auth-email", root).value.trim();
    const pw = qs("#auth-pw", root).value;
    const name = qs("#auth-name", root)?.value.trim();
    try {
      if (root.dataset.authMode === "signup") await backend.signUp(email, pw, name || email.split("@")[0]);
      else await backend.signIn(email, pw);
      await boot(true);
    } catch (ex) {
      btn.disabled = false;
      showErr(ex.message === "CONFIRM_EMAIL"
        ? "Account created — check your email to confirm, then sign in."
        : ex.message || "Sign in failed");
    }
  });
}

/* ---------- boot ---------- */
async function boot(afterAuth = false) {
  applyTheme(prefs.get("theme", "system"));
  await refreshUser();

  if (state.user) {
    await refreshLeagues();
    const want = prefs.get("leagueId");
    const pick = state.leagues.find((l) => String(l.id) === String(want)) || state.leagues[0];
    invalidate();
    await selectLeague(pick?.id || null);
    if (afterAuth && !location.hash) location.hash = "#/dashboard";
  }
  await render();
}

window.addEventListener("hashchange", () => { closeModal(); render(); });
window.addEventListener("error", (e) => console.error("[predictor]", e.error || e.message));

boot().catch((e) => {
  console.error(e);
  document.body.innerHTML = `<pre style="padding:24px;font:13px monospace;white-space:pre-wrap">
Predictor failed to start.

${e.stack || e.message}
</pre>`;
});

/* expose for views that need a full refresh after a mutation */
export { api, state, isAdmin, parseHash, navigate };
