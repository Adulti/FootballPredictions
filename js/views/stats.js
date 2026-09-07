import { html, raw, icon, qs, fmt1, emptyState, initials } from "../lib/ui.js";
import { state } from "../lib/store.js";
import { derived, myEntrant } from "../lib/derive.js";
import { headToHead, hasResult } from "../lib/scoring.js";
import { renderBarChart, renderLineChart } from "../lib/charts.js";

export const title = "Stats & records";

export async function render(host) {
  const { tal, table, recs } = derived();

  if (!tal.completedGameweeks.length) {
    host.innerHTML = emptyState({
      mark: "📊", title: "Stats appear once results are in",
      body: "Enter the scores for a gameweek and this page fills up with records, accuracy breakdowns and head-to-heads.",
      action: `<a class="btn btn--primary" href="#/fixtures">Enter results</a>`,
    });
    return;
  }

  const me = myEntrant();
  let focusId = (me && table.find((r) => r.entrantId === String(me.id))?.entrantId) || table[0].entrantId;
  let rivalId = table.find((r) => r.entrantId !== focusId)?.entrantId || focusId;

  const paint = () => {
    const row = table.find((r) => r.entrantId === focusId);
    const rival = table.find((r) => r.entrantId === rivalId);
    const h2h = rival ? headToHead(tal, state.entrants, focusId, rivalId) : null;
    const dist = scorelineFrequency();

    host.innerHTML = html`
    <div class="stack">
      <div class="grid grid--stats">
        ${raw([
          ["Best week", recs.bestWeek ? `${recs.bestWeek.points} pts` : "—", recs.bestWeek ? `${recs.bestWeek.name} · GW${recs.bestWeek.gw}` : ""],
          ["Most exact scores", recs.mostExact ? recs.mostExact.exact : "—", recs.mostExact ? recs.mostExact.name : ""],
          ["Most weekly wins", recs.mostWeekWins ? recs.mostWeekWins.wins : "—", recs.mostWeekWins ? recs.mostWeekWins.name : ""],
          ["League average", fmt1(table.reduce((a, r) => a + r.points, 0) / Math.max(1, table.length)), "points per entrant"],
        ].map(([l, v, s]) => html`
          <div class="stat"><div class="stat__label">${l}</div><div class="stat__value">${v}</div><div class="stat__sub">${s}</div></div>`).join(""))}
      </div>

      <div class="card">
        <div class="card__head">
          <h3>Entrant profile</h3>
          <div class="field" style="min-width:230px">
            <label class="sr-only" for="focus">Entrant</label>
            <select class="select" id="focus">
              ${raw(table.map((r) => `<option value="${r.entrantId}" ${r.entrantId === focusId ? "selected" : ""}>${r.name}${r.team ? ` — ${r.team}` : ""}</option>`).join(""))}
            </select>
          </div>
        </div>
        <div class="card__body stack">
          <div class="row" style="gap:14px">
            <div class="avatar avatar--lg">${initials(row.name)}</div>
            <div>
              <div style="font-weight:650;font-size:16px">${row.name}</div>
              <div class="muted" style="font-size:12.5px">${row.team || "—"} · ${ordinal(row.rank)} of ${table.length}</div>
            </div>
            <div class="spacer"></div>
            <div class="scorekey">
              <span class="scorekey__item"><b class="mono">${row.points}</b> pts</span>
              <span class="scorekey__item"><b class="mono">${fmt1(row.avg)}</b> avg</span>
              <span class="scorekey__item"><b class="mono">${row.best ?? "—"}</b> best</span>
              <span class="scorekey__item"><b class="mono">${row.worst ?? "—"}</b> worst</span>
            </div>
          </div>

          <div class="grid grid--form">
            ${raw([
              ["Exact scores", row.exact, "var(--good)"],
              ["Goal difference", row.gd, "var(--accent)"],
              ["Outcome only", row.outcome, "var(--text-secondary)"],
              ["Wrong", row.wrong, "var(--bad)"],
              ["Hit rate", `${Math.round(row.hitRate * 100)}%`, "var(--text-primary)"],
              ["Banker extra", `${row.bonusPoints >= 0 ? "+" : ""}${row.bonusPoints}`, "var(--warn)"],
            ].map(([l, v, c]) => html`
              <div class="stat" style="padding:11px 13px">
                <div class="stat__label">${l}</div>
                <div class="stat__value" style="font-size:21px;color:${c}">${v}</div>
              </div>`).join(""))}
          </div>

          <div>
            <div class="section-title"><h2 style="font-size:14px">Points by gameweek</h2></div>
            <div id="bar-chart"></div>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card__head">
          <h3>Head to head</h3>
          <div class="field" style="min-width:220px">
            <label class="sr-only" for="rival">Compare with</label>
            <select class="select" id="rival">
              ${raw(table.filter((r) => r.entrantId !== focusId).map((r) => `<option value="${r.entrantId}" ${r.entrantId === rivalId ? "selected" : ""}>${r.name}</option>`).join(""))}
            </select>
          </div>
        </div>
        <div class="card__body stack">
          ${h2h ? html`
          <div class="row" style="justify-content:center;gap:22px">
            <div style="text-align:right;flex:1">
              <div style="font-weight:650">${row.name}</div>
              <div class="mono" style="font-size:26px;font-weight:700;color:var(--series-1)">${h2h.aWins}</div>
              <div class="muted" style="font-size:12px">weeks won</div>
            </div>
            <div style="text-align:center">
              <div class="pill">${h2h.draws} drawn</div>
              <div class="muted mono" style="margin-top:8px;font-size:12.5px">${row.points} – ${rival.points}</div>
              <div class="muted" style="font-size:11.5px">total points</div>
            </div>
            <div style="flex:1">
              <div style="font-weight:650">${rival.name}</div>
              <div class="mono" style="font-size:26px;font-weight:700;color:var(--series-2)">${h2h.bWins}</div>
              <div class="muted" style="font-size:12px">weeks won</div>
            </div>
          </div>
          <div id="h2h-chart"></div>
          <div class="table-wrap">
            <table class="tbl">
              <thead><tr><th>GW</th><th class="num">${row.name}</th><th class="num">${rival.name}</th><th class="ctr">Week</th></tr></thead>
              <tbody>${raw(h2h.weeks.map((w) => html`<tr>
                <td class="mono">GW${w.gw}</td>
                <td class="num mono">${w.a}</td>
                <td class="num mono">${w.b}</td>
                <td class="ctr">${w.a === w.b ? html`<span class="pill">tie</span>`
                  : html`<span class="pill ${w.a > w.b ? "pill--accent" : "pill--warn"}">${w.a > w.b ? row.name.split(" ")[0] : rival.name.split(" ")[0]}</span>`}</td>
              </tr>`).join(""))}</tbody>
            </table>
          </div>` : html`<p class="muted">Add another entrant to compare.</p>`}
        </div>
      </div>

      <div class="grid grid--2">
        <div class="card">
          <div class="card__head"><h3>Weekly winners</h3></div>
          <div class="card__body card__body--flush table-wrap">
            <table class="tbl">
              <thead><tr><th>Entrant</th><th class="num">Weeks won</th><th class="num">Weeks played</th></tr></thead>
              <tbody>${raw([...table]
                .map((r) => ({ ...r, wins: recs.weekWins.get(r.entrantId) || 0 }))
                .sort((a, b) => b.wins - a.wins || b.points - a.points)
                .map((r) => html`<tr>
                  <td><div class="who"><span class="who__name">${r.name}</span><span class="who__team">${r.team || ""}</span></div></td>
                  <td class="num mono"><b>${r.wins}</b></td>
                  <td class="num mono">${r.weeks}</td>
                </tr>`).join(""))}</tbody>
            </table>
          </div>
        </div>

        <div class="card">
          <div class="card__head">
            <h3>Most-predicted scorelines</h3>
            <span class="muted" style="font-size:12.5px">across the whole league</span>
          </div>
          <div class="card__body card__body--flush table-wrap">
            <table class="tbl">
              <thead><tr><th>Scoreline</th><th class="num">Times predicted</th><th class="num">Landed</th><th class="num">Hit rate</th></tr></thead>
              <tbody>${raw(dist.slice(0, 10).map((d) => html`<tr>
                <td class="mono"><b>${d.score}</b></td>
                <td class="num mono">${d.count}</td>
                <td class="num mono">${d.hits}</td>
                <td class="num mono">${d.count ? Math.round((d.hits / d.count) * 100) : 0}%</td>
              </tr>`).join(""))}</tbody>
            </table>
          </div>
        </div>
      </div>
    </div>`;

    /* charts */
    const gws = tal.completedGameweeks;
    renderBarChart(qs("#bar-chart", host), {
      labels: gws,
      values: gws.map((g) => tal.byGw.get(g)?.get(focusId)?.points ?? 0),
      aria: `${row.name} points by gameweek`,
    });

    if (h2h) {
      let ca = 0, cb = 0;
      renderLineChart(qs("#h2h-chart", host), {
        x: h2h.weeks.map((w) => w.gw),
        series: [
          { id: "a", name: row.name, values: h2h.weeks.map((w) => (ca += w.a)) },
          { id: "b", name: rival.name, values: h2h.weeks.map((w) => (cb += w.b)) },
        ],
        aria: `Cumulative points: ${row.name} versus ${rival.name}`,
        height: 220,
      });
    }

    qs("#focus", host).addEventListener("change", (e) => {
      focusId = e.target.value;
      if (rivalId === focusId) rivalId = table.find((r) => r.entrantId !== focusId)?.entrantId || focusId;
      paint();
    });
    qs("#rival", host)?.addEventListener("change", (e) => { rivalId = e.target.value; paint(); });
  };

  paint();
}

function scorelineFrequency() {
  const fxById = new Map(state.fixtures.map((f) => [String(f.id), f]));
  const m = new Map();
  for (const p of state.predictions) {
    if (p.home_score === null || p.away_score === null) continue;
    const key = `${p.home_score}–${p.away_score}`;
    const e = m.get(key) || { score: key, count: 0, hits: 0 };
    e.count += 1;
    const fx = fxById.get(String(p.fixture_id));
    if (fx && hasResult(fx) && Number(fx.home_score) === Number(p.home_score) && Number(fx.away_score) === Number(p.away_score)) e.hits += 1;
    m.set(key, e);
  }
  return [...m.values()].sort((a, b) => b.count - a.count);
}

function ordinal(n) {
  const s = ["th", "st", "nd", "rd"], v = n % 100;
  return n + (s[(v - 20) % 10] || s[v] || s[0]);
}
