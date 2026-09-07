import { html, raw, icon, qs, fmt1, emptyState, copyText, initials } from "../lib/ui.js";
import { state, isAdmin } from "../lib/store.js";
import { derived, myEntrant, latestCompletedGw, nextOpenGw, fixturesFor } from "../lib/derive.js";
import { gameweekStandings, hasResult } from "../lib/scoring.js";
import { renderLineChart } from "../lib/charts.js";
import { standingsAsOf, formStrip } from "./table.js";

export const title = "Overview";

export async function render(host) {
  const { tal, table, recs } = derived();
  const admin = isAdmin();

  if (!state.entrants.length || !state.fixtures.length) {
    host.innerHTML = html`
      <div class="stack">
        <div class="card"><div class="card__body">
          ${raw(emptyState({
            mark: "🚀", title: `Let's get ${state.league.name} started`,
            body: "Three steps: add the entrants, add the fixtures, then enter everyone's predictions. Results and tables follow automatically.",
          }))}
          <div class="row" style="justify-content:center;margin-top:4px">
            <a class="btn ${state.entrants.length ? "" : "btn--primary"}" href="#/entrants">${icon("users", 15)} 1. Entrants ${state.entrants.length ? `(${state.entrants.length})` : ""}</a>
            <a class="btn ${state.entrants.length && !state.fixtures.length ? "btn--primary" : ""}" href="#/fixtures">${icon("clock", 15)} 2. Fixtures ${state.fixtures.length ? `(${state.fixtures.length})` : ""}</a>
            <a class="btn" href="#/predictions">${icon("edit", 15)} 3. Predictions</a>
          </div>
        </div></div>
        ${joinCard()}
      </div>`;
    wireJoin(host);
    return;
  }

  const me = myEntrant();
  const meRow = me ? table.find((r) => r.entrantId === String(me.id)) : null;
  const leader = table[0];
  const lastGw = latestCompletedGw();
  const openGw = nextOpenGw();
  const lastWeek = lastGw !== null ? gameweekStandings(tal, state.entrants, lastGw) : [];
  const weekWinners = lastWeek.filter((r) => r.rank === 1 && r.played > 0);
  const totalPreds = state.predictions.length;
  const resultsIn = state.fixtures.filter(hasResult).length;

  host.innerHTML = html`
  <div class="stack">
    <div class="grid grid--stats">
      <div class="stat">
        <div class="stat__label">Leader</div>
        <div class="stat__value" style="font-size:20px">${leader ? leader.name : "—"}</div>
        <div class="stat__sub">${leader ? `${leader.points} pts · ${leader.exact} exact` : "No results yet"}</div>
      </div>
      ${meRow ? html`
      <div class="stat">
        <div class="stat__label">Your position</div>
        <div class="stat__value">${meRow.rank}<span style="font-size:14px;color:var(--text-muted)"> / ${table.length}</span></div>
        <div class="stat__sub">${meRow.points} pts · ${leader && meRow.rank > 1 ? `${leader.points - meRow.points} behind` : "top of the pile"}</div>
      </div>` : html`
      <div class="stat">
        <div class="stat__label">Entrants</div>
        <div class="stat__value">${state.entrants.length}</div>
        <div class="stat__sub">${admin ? html`<a href="#/entrants">Manage entrants</a>` : "in this league"}</div>
      </div>`}
      <div class="stat">
        <div class="stat__label">Gameweeks played</div>
        <div class="stat__value">${tal.completedGameweeks.length}<span style="font-size:14px;color:var(--text-muted)"> / ${tal.gameweeks.length}</span></div>
        <div class="stat__sub">${resultsIn} of ${state.fixtures.length} fixtures scored</div>
      </div>
      <div class="stat">
        <div class="stat__label">Last week's winner</div>
        <div class="stat__value" style="font-size:20px">${weekWinners.length ? weekWinners.map((w) => w.name).join(", ") : "—"}</div>
        <div class="stat__sub">${weekWinners.length ? `${weekWinners[0].points} pts in GW${lastGw}` : "Awaiting results"}</div>
      </div>
    </div>

    ${openGw !== null ? html`
    <div class="card">
      <div class="card__head">
        <h3>Coming up — gameweek ${openGw}</h3>
        <span class="pill">${fixturesFor(openGw).length} fixtures</span>
        ${admin ? raw(`<a class="btn btn--sm" href="#/predictions/${openGw}">${icon("edit", 14).value} Enter predictions</a>
                       <a class="btn btn--sm" href="#/fixtures">${icon("clock", 14).value} Enter results</a>`) : ""}
      </div>
      <div class="card__body stack stack--sm">
        ${raw(fixturesFor(openGw).map((f) => {
          const done = state.entrants.filter((e) => state.predictions.some((p) => p.fixture_id === f.id && p.entrant_id === e.id)).length;
          return html`<div class="row" style="justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--border)">
            <div class="fx" style="flex:1;max-width:420px">
              <span class="fx__home">${f.home_team}</span>
              <span class="fx__score fx__score--empty">v</span>
              <span class="fx__away">${f.away_team}</span>
            </div>
            <span class="pill ${done === state.entrants.length ? "pill--good" : done ? "pill--warn" : ""}">${done}/${state.entrants.length} predicted</span>
          </div>`;
        }).join(""))}
      </div>
    </div>` : ""}

    <div class="grid grid--2">
      <div class="card">
        <div class="card__head">
          <h3>Top of the table</h3>
          <a class="btn btn--sm btn--ghost" href="#/table">Full table ${icon("chevronRight", 14)}</a>
        </div>
        <div class="card__body card__body--flush table-wrap">
          <table class="tbl">
            <thead><tr><th>#</th><th>Entrant</th><th class="num">Pts</th><th>Form</th></tr></thead>
            <tbody>${raw(standingsAsOf(tal, state.entrants, null).slice(0, 6).map((r) => html`
              <tr class="${me && r.entrantId === String(me.id) ? "is-me" : ""}">
                <td><span class="rank ${r.rank <= 3 ? `rank--${r.rank}` : ""}">${r.rank}</span></td>
                <td><div class="who"><span class="who__name">${r.name}</span><span class="who__team">${r.team || ""}</span></div></td>
                <td class="num mono"><b>${r.points}</b></td>
                <td>${formStrip(tal, r.entrantId, 5)}</td>
              </tr>`).join(""))}
            </tbody>
          </table>
        </div>
      </div>

      <div class="card">
        <div class="card__head">
          <h3>Records</h3>
          <a class="btn btn--sm btn--ghost" href="#/stats">All stats ${icon("chevronRight", 14)}</a>
        </div>
        <div class="card__body stack stack--sm">
          ${raw([
            ["🔥", "Best single week", recs.bestWeek ? `${recs.bestWeek.name} — ${recs.bestWeek.points} pts (GW${recs.bestWeek.gw})` : "—"],
            ["🎯", "Most exact scores", recs.mostExact && recs.mostExact.exact ? `${recs.mostExact.name} — ${recs.mostExact.exact}` : "—"],
            ["🏅", "Most weekly wins", recs.mostWeekWins ? `${recs.mostWeekWins.name} — ${recs.mostWeekWins.wins}` : "—"],
            ["⚡", "Best banker haul", recs.bestBonus && recs.bestBonus.bonusPoints ? `${recs.bestBonus.name} — +${recs.bestBonus.bonusPoints} extra` : "—"],
            ["🥶", "Worst week", recs.worstWeek ? `${recs.worstWeek.name} — ${recs.worstWeek.points} pts (GW${recs.worstWeek.gw})` : "—"],
          ].map(([em, label, val]) => html`
            <div class="row" style="justify-content:space-between;gap:12px;padding:5px 0;border-bottom:1px solid var(--border)">
              <span class="muted" style="font-size:12.5px">${em} ${label}</span>
              <span style="font-weight:600;text-align:right">${val}</span>
            </div>`).join(""))}
        </div>
      </div>
    </div>

    ${tal.completedGameweeks.length > 1 ? html`
    <div class="card">
      <div class="card__head">
        <h3>Points progression</h3>
        <span class="muted" style="font-size:12.5px">Cumulative points — top 5 highlighted, everyone else in grey</span>
      </div>
      <div class="card__body">
        <div id="prog-chart"></div>
        <p class="muted" style="font-size:12px;margin-top:8px">
          The same numbers are in the <a href="#/table">league table</a> and <a href="#/history">table history</a>.
        </p>
      </div>
    </div>` : ""}

    ${joinCard()}
  </div>`;

  if (tal.completedGameweeks.length > 1) {
    const gws = tal.completedGameweeks;
    const cum = (eid) => { let t = 0; return gws.map((gw) => (t += tal.byGw.get(gw)?.get(eid)?.points ?? 0)); };
    const highlight = table.slice(0, 5);
    if (me && !highlight.some((r) => r.entrantId === String(me.id))) {
      const meR = table.find((r) => r.entrantId === String(me.id));
      if (meR) { highlight.pop(); highlight.push(meR); }
    }
    const hl = new Set(highlight.map((r) => r.entrantId));
    renderLineChart(qs("#prog-chart", host), {
      x: gws,
      series: highlight.map((r) => ({ id: r.entrantId, name: r.name, values: cum(r.entrantId) })),
      context: table.filter((r) => !hl.has(r.entrantId)).map((r) => ({ id: r.entrantId, name: r.name, values: cum(r.entrantId) })),
      aria: "Cumulative points by gameweek for each entrant",
      height: 280,
    });
  }

  wireJoin(host);
}

function joinCard() {
  const L = state.league;
  if (!L?.join_code) return "";
  return html`
    <div class="card">
      <div class="card__head"><h3>Invite people to follow this league</h3></div>
      <div class="card__body row" style="gap:10px">
        <span class="muted" style="font-size:12.5px">Share this join code — they'll be able to view the tables and results.</span>
        <div class="spacer"></div>
        <code class="mono" style="padding:6px 12px;background:var(--surface-2);border:1px solid var(--border);border-radius:8px;font-weight:600;letter-spacing:.1em">${L.join_code}</code>
        <button class="btn btn--sm" id="copy-code">${icon("copy", 14)} Copy</button>
      </div>
    </div>`;
}

function wireJoin(host) {
  qs("#copy-code", host)?.addEventListener("click", () => copyText(state.league.join_code));
}
