import { html, raw, icon, qs, rankClass, movementBadge, downloadCsv, emptyState } from "../lib/ui.js";
import { state } from "../lib/store.js";
import { derived, myEntrant } from "../lib/derive.js";
import { renderLineChart } from "../lib/charts.js";

export const title = "Table history";

export async function render(host) {
  const { tal, hist, table } = derived();

  if (!hist.length) {
    host.innerHTML = emptyState({
      mark: "🕰️", title: "No history yet",
      body: "As soon as one gameweek has results, a snapshot of the table is kept for every week — you'll be able to step back through them here.",
    });
    return;
  }

  let i = hist.length - 1;   // index into hist
  const me = myEntrant();

  const paint = () => {
    const snap = hist[i];

    host.innerHTML = html`
    <div class="stack">
      <div class="row">
        <button class="btn btn--icon" id="prev" ${i === 0 ? "disabled" : ""} title="Earlier gameweek">${icon("chevronLeft")}</button>
        <div class="field" style="min-width:210px">
          <label class="sr-only" for="snapsel">Snapshot</label>
          <select class="select" id="snapsel">
            ${raw(hist.map((s, n) => `<option value="${n}" ${n === i ? "selected" : ""}>Table after gameweek ${s.gw}</option>`).join(""))}
          </select>
        </div>
        <button class="btn btn--icon" id="next" ${i === hist.length - 1 ? "disabled" : ""} title="Later gameweek">${icon("chevronRight")}</button>
        <input class="input" id="scrub" type="range" min="0" max="${hist.length - 1}" value="${i}"
               style="max-width:260px;padding:0;min-height:auto;background:none;border:0" aria-label="Scrub through gameweeks" />
        <div class="spacer"></div>
        <button class="btn btn--sm" id="csv">${icon("download", 15)} CSV</button>
      </div>

      <div class="card">
        <div class="card__head">
          <h3>Standings after gameweek ${snap.gw}</h3>
          <span class="pill">${i + 1} of ${hist.length} snapshots</span>
          <span class="pill pill--accent">🏆 ${snap.rows[0].name}</span>
        </div>
        <div class="card__body card__body--flush table-wrap">
          <table class="tbl">
            <thead><tr>
              <th>#</th><th class="ctr">+/−</th><th>Entrant</th>
              <th class="num">Total</th><th class="num">GW${snap.gw}</th>
              <th class="num">Exact</th><th class="num">GD</th><th class="num">Out</th><th class="num">Miss</th>
              <th class="num">Gap to top</th>
            </tr></thead>
            <tbody>
              ${raw(snap.rows.map((r) => html`
                <tr class="${me && r.entrantId === String(me.id) ? "is-me" : ""}">
                  <td><span class="${rankClass(r.rank)}">${r.rank}${r.tied ? "=" : ""}</span></td>
                  <td class="ctr">${movementBadge(r.movement)}</td>
                  <td><div class="who"><span class="who__name">${r.name}</span><span class="who__team">${r.team || ""}</span></div></td>
                  <td class="num mono"><b>${r.points}</b></td>
                  <td class="num mono">${r.perGw[snap.gw] ?? 0}</td>
                  <td class="num mono">${r.exact}</td>
                  <td class="num mono">${r.gd}</td>
                  <td class="num mono">${r.outcome}</td>
                  <td class="num mono" style="color:var(--bad)">${r.wrong}</td>
                  <td class="num mono muted">${snap.rows[0].points - r.points === 0 ? "—" : `−${snap.rows[0].points - r.points}`}</td>
                </tr>`).join(""))}
            </tbody>
          </table>
        </div>
      </div>

      <div class="grid grid--2">
        <div class="card">
          <div class="card__head"><h3>Who led each week</h3></div>
          <div class="card__body card__body--flush table-wrap">
            <table class="tbl">
              <thead><tr><th>GW</th><th>Leader</th><th class="num">Pts</th><th>Weekly winner</th></tr></thead>
              <tbody>
                ${raw(hist.map((s) => {
                  const weekTop = [...s.rows].sort((a, b) => (b.perGw[s.gw] ?? 0) - (a.perGw[s.gw] ?? 0))[0];
                  return html`<tr>
                    <td class="mono">GW${s.gw}</td>
                    <td>${s.rows[0].name}${s.rows.filter((r) => r.rank === 1).length > 1 ? " (tied)" : ""}</td>
                    <td class="num mono">${s.rows[0].points}</td>
                    <td>${weekTop.name} <span class="pill">${weekTop.perGw[s.gw] ?? 0}</span></td>
                  </tr>`;
                }).join(""))}
              </tbody>
            </table>
          </div>
        </div>

        <div class="card">
          <div class="card__head">
            <h3>Position race</h3>
            <span class="muted" style="font-size:12.5px">1st at the top</span>
          </div>
          <div class="card__body">
            <div id="race-chart"></div>
            <p class="muted" style="font-size:12px;margin-top:8px">
              Top 5 highlighted; the rest are grey context lines. Exact positions are in the snapshot table above.
            </p>
          </div>
        </div>
      </div>
    </div>`;

    const go = (n) => { i = Math.max(0, Math.min(hist.length - 1, n)); paint(); };
    qs("#prev", host).addEventListener("click", () => go(i - 1));
    qs("#next", host).addEventListener("click", () => go(i + 1));
    qs("#snapsel", host).addEventListener("change", (e) => go(Number(e.target.value)));
    qs("#scrub", host).addEventListener("input", (e) => go(Number(e.target.value)));
    qs("#csv", host).addEventListener("click", () => {
      const head = ["Rank", "Full name", "Team", "Total", `GW${snap.gw}`, "Exact", "GD", "Outcome", "Wrong", "Movement"];
      downloadCsv(`${state.league.name} — table after GW${snap.gw}.csv`, [head, ...snap.rows.map((r) => [
        r.rank, r.name, r.team, r.points, r.perGw[snap.gw] ?? 0, r.exact, r.gd, r.outcome, r.wrong,
        r.movement === null ? "new" : r.movement,
      ])]);
    });

    /* rank race */
    const gws = hist.map((s) => s.gw);
    const rankSeries = (eid) => hist.map((s) => s.rows.find((r) => r.entrantId === eid)?.rank ?? state.entrants.length);
    const top = table.slice(0, 5);
    const hl = new Set(top.map((r) => r.entrantId));
    renderLineChart(qs("#race-chart", host), {
      x: gws, invertY: true,
      series: top.map((r) => ({ id: r.entrantId, name: r.name, values: rankSeries(r.entrantId) })),
      context: table.filter((r) => !hl.has(r.entrantId)).map((r) => ({ id: r.entrantId, name: r.name, values: rankSeries(r.entrantId) })),
      aria: "League position by gameweek",
      height: 250,
    });
  };

  paint();
}
