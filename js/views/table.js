import { html, raw, icon, movementBadge, rankClass, fmt1, downloadCsv, on, qs, emptyState } from "../lib/ui.js";
import { state } from "../lib/store.js";
import { derived, myEntrant } from "../lib/derive.js";
import { standings, formFor } from "../lib/scoring.js";

export const title = "League table";

/** Standings as of `gw` (null = all time), with movement vs the previous completed week. */
export function standingsAsOf(tal, entrants, gw) {
  const rows = standings(tal, entrants, gw).map((r) => ({ ...r }));
  const done = tal.completedGameweeks;
  const idx = gw === null ? done.length - 1 : done.indexOf(gw);
  const prevGw = idx > 0 ? done[idx - 1] : null;
  if (prevGw !== null) {
    const prev = new Map(standings(tal, entrants, prevGw).map((r) => [r.entrantId, r.rank]));
    for (const r of rows) {
      const p = prev.get(r.entrantId) ?? null;
      r.prevRank = p;
      r.movement = p === null ? null : p - r.rank;
    }
  } else {
    for (const r of rows) { r.prevRank = null; r.movement = null; }
  }
  return rows;
}

export function formStrip(tal, entrantId, n = 6) {
  const pts = formFor(tal, entrantId, n);
  if (!pts.length) return html`<span class="muted">—</span>`;
  const max = Math.max(1, ...pts.map((p) => Math.abs(p.points)));
  return raw(`<span class="form-strip" title="${pts.map((p) => `GW${p.gw}: ${p.points}`).join(" · ")}">` +
    pts.map((p) => {
      const t = p.points < 0 ? "wrong" : p.points >= max * 0.8 ? "exact" : p.points >= max * 0.45 ? "gd" : "outcome";
      return `<i data-t="${t}" style="height:${Math.max(6, Math.round(18 * (Math.abs(p.points) / max)))}px"></i>`;
    }).join("") + `</span>`);
}

export function tableRows(rows, tal, { showForm = true } = {}) {
  const me = myEntrant();
  return rows.map((r) => html`
    <tr class="${me && r.entrantId === String(me.id) ? "is-me" : ""}">
      <td><span class="${rankClass(r.rank)}">${r.rank}${r.tied ? "=" : ""}</span></td>
      <td class="ctr">${movementBadge(r.movement)}</td>
      <td>
        <div class="row" style="gap:9px;flex-wrap:nowrap">
          <div class="avatar">${r.name.split(/\s+/).map((p) => p[0]).slice(0, 2).join("").toUpperCase()}</div>
          <div class="who">
            <span class="who__name">${r.name}</span>
            <span class="who__team">${r.team || "—"}</span>
          </div>
        </div>
      </td>
      <td class="num"><b class="mono" style="font-size:14.5px">${r.points}</b></td>
      <td class="num mono">${r.exact}</td>
      <td class="num mono">${r.gd}</td>
      <td class="num mono">${r.outcome}</td>
      <td class="num mono" style="color:var(--bad)">${r.wrong}</td>
      <td class="num mono" style="color:var(--bad)">${r.missing}</td>
      <td class="num mono">${fmt1(r.avg)}</td>
      <td class="num mono">${r.bonusPoints >= 0 ? `+${r.bonusPoints}` : r.bonusPoints}</td>
      ${showForm ? html`<td>${formStrip(tal, r.entrantId)}</td>` : ""}
    </tr>`).join("");
}

export async function render(host) {
  const { tal } = derived();

  if (!state.entrants.length) {
    host.innerHTML = emptyState({
      mark: "👥", title: "No entrants yet",
      body: "Add the people playing — full name plus their team name — and the table will build itself.",
      action: `<a class="btn btn--primary" href="#/entrants">Add entrants</a>`,
    });
    return;
  }

  const done = tal.completedGameweeks;
  let asOf = null; // null = all time

  const paint = () => {
    const rows = standingsAsOf(tal, state.entrants, asOf);
    const rules = tal.rules;
    host.innerHTML = html`
      <div class="stack">
        <div class="card">
          <div class="card__head">
            <h2>${asOf === null ? "Current standings" : `Table after gameweek ${asOf}`}</h2>
            <div class="field" style="min-width:190px">
              <label class="sr-only" for="asof">Show table as of</label>
              <select class="select" id="asof">
                <option value="">All time (latest)</option>
                ${raw(done.map((gw) => `<option value="${gw}" ${String(asOf) === String(gw) ? "selected" : ""}>After gameweek ${gw}</option>`).join(""))}
              </select>
            </div>
            <button class="btn btn--sm" id="csv">${icon("download", 15)} CSV</button>
            <button class="btn btn--sm" id="print">${icon("print", 15)} Print</button>
          </div>

          ${done.length ? html`
          <div class="table-wrap">
            <table class="tbl">
              <thead><tr>
                <th>#</th><th class="ctr" title="Movement since the previous gameweek">+/−</th>
                <th>Entrant</th>
                <th class="num">Pts</th>
                <th class="num" title="Exact scores (${rules.exact} pts)">Exact</th>
                <th class="num" title="Goal difference correct (${rules.gd} pts)">GD</th>
                <th class="num" title="Outcome correct (${rules.outcome} pts)">Out</th>
                <th class="num" title="Wrong (${rules.wrong} pts)">Miss</th>
                <th class="num" title="No prediction submitted (${rules.missed} pts)">None</th>
                <th class="num" title="Average points per gameweek played">Avg</th>
                <th class="num" title="Extra points earned from bankers">Bonus</th>
                <th title="Last 6 gameweeks, oldest first">Form</th>
              </tr></thead>
              <tbody>${raw(tableRows(rows, tal))}</tbody>
            </table>
          </div>` : raw(emptyState({
            mark: "⏳", title: "No results yet",
            body: "Once you enter scores for a gameweek's fixtures the table will populate.",
            action: `<a class="btn btn--primary" href="#/fixtures">Enter results</a>`,
          }))}
        </div>

        <div class="card">
          <div class="card__head"><h3>How points work</h3></div>
          <div class="card__body">
            <div class="scorekey">
              <span class="scorekey__item"><span class="pts pts--exact">${rules.exact >= 0 ? "+" : ""}${rules.exact}</span> Exact score</span>
              <span class="scorekey__item"><span class="pts pts--gd">${rules.gd >= 0 ? "+" : ""}${rules.gd}</span> Goal difference right</span>
              <span class="scorekey__item"><span class="pts pts--outcome">${rules.outcome >= 0 ? "+" : ""}${rules.outcome}</span> Right outcome</span>
              <span class="scorekey__item"><span class="pts pts--wrong">${rules.wrong}</span> Wrong</span>
              <span class="scorekey__item"><span class="pts pts--wrong">${rules.missed}</span> No prediction</span>
              <span class="scorekey__item"><span class="pill pill--bonus">×${rules.bonusMultiplier}</span> Banker (one fixture per week)</span>
            </div>
            <p class="muted" style="margin-top:10px;font-size:12.5px">
              Ties are split by exact scores, then goal-difference hits, then name.
            </p>
          </div>
        </div>
      </div>`;

    qs("#asof", host).addEventListener("change", (e) => {
      asOf = e.target.value === "" ? null : Number(e.target.value);
      paint();
    });
    qs("#print", host).addEventListener("click", () => window.print());
    qs("#csv", host).addEventListener("click", () => {
      const head = ["Rank", "Full name", "Team name", "Points", "Exact", "GD", "Outcome", "Wrong", "No prediction", "Played", "Avg", "Bonus pts"];
      const body = rows.map((r) => [r.rank, r.name, r.team, r.points, r.exact, r.gd, r.outcome, r.wrong, r.missing, r.played, fmt1(r.avg), r.bonusPoints]);
      downloadCsv(`${state.league.name} — table${asOf === null ? "" : ` after GW${asOf}`}.csv`, [head, ...body]);
    });
  };

  paint();
}
