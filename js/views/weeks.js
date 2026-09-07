import { html, raw, icon, qs, qsa, on, rankClass, downloadCsv, emptyState, fmtDateTime } from "../lib/ui.js";
import { state } from "../lib/store.js";
import { derived, myEntrant, fixturesFor, predIndex, latestCompletedGw } from "../lib/derive.js";
import { gameweekStandings, hasResult, KIND_LABELS } from "../lib/scoring.js";
import { parseHash } from "../lib/router.js";

export const title = "Weekly results";

const ptsChip = (res) => {
  if (!res || res.kind === "pending") return html`<span class="pts pts--none">–</span>`;
  if (res.kind === "none") return res.points
    ? html`<span class="pts pts--wrong" title="No prediction">${res.points}</span>`
    : html`<span class="pts pts--none" title="No prediction">·</span>`;
  return html`<span class="pts pts--${res.kind}" title="${KIND_LABELS[res.kind]}${res.bonus ? " (banker ×2)" : ""}">${res.points > 0 ? "+" : ""}${res.points}</span>`;
};

export async function render(host) {
  const { tal } = derived();
  if (!tal.gameweeks.length) {
    host.innerHTML = emptyState({
      mark: "📅", title: "No gameweeks yet",
      body: "Add fixtures and give each one a gameweek number — then weekly results appear here.",
      action: `<a class="btn btn--primary" href="#/fixtures">Add fixtures</a>`,
    });
    return;
  }

  const fromHash = Number(parseHash().params[0]);
  let gw = tal.gameweeks.includes(fromHash) ? fromHash : (latestCompletedGw() ?? tal.gameweeks[0]);

  const paint = () => {
    const fixtures = fixturesFor(gw);
    const idx = predIndex();
    const rows = gameweekStandings(tal, state.entrants, gw);
    const me = myEntrant();
    const pos = tal.gameweeks.indexOf(gw);
    const played = fixtures.filter(hasResult).length;

    host.innerHTML = html`
    <div class="stack">
      <div class="row">
        <button class="btn btn--icon" id="prev" ${pos <= 0 ? "disabled" : ""} title="Previous gameweek">${icon("chevronLeft")}</button>
        <div class="field" style="min-width:170px">
          <label class="sr-only" for="gwsel">Gameweek</label>
          <select class="select" id="gwsel">
            ${raw(tal.gameweeks.map((g) => `<option value="${g}" ${g === gw ? "selected" : ""}>Gameweek ${g}${tal.completedGameweeks.includes(g) ? "" : " (open)"}</option>`).join(""))}
          </select>
        </div>
        <button class="btn btn--icon" id="next" ${pos >= tal.gameweeks.length - 1 ? "disabled" : ""} title="Next gameweek">${icon("chevronRight")}</button>
        <span class="pill ${played === fixtures.length ? "pill--good" : "pill--warn"}">${played}/${fixtures.length} results in</span>
        <div class="spacer"></div>
        <button class="btn btn--sm" id="csv">${icon("download", 15)} CSV</button>
      </div>

      <div class="card">
        <div class="card__head"><h3>Results — gameweek ${gw}</h3></div>
        <div class="card__body card__body--flush table-wrap">
          <table class="tbl">
            <thead><tr><th>Fixture</th><th class="ctr">Result</th><th>Kick-off</th><th class="num">Exact hits</th></tr></thead>
            <tbody>
              ${raw(fixtures.map((f) => {
                const exacts = state.entrants.reduce((n, e) => {
                  const r = tal.cells.get(`${f.id}|${e.id}`);
                  return n + (r && r.kind === "exact" ? 1 : 0);
                }, 0);
                return html`<tr>
                  <td><div class="fx" style="max-width:360px">
                    <span class="fx__home">${f.home_team}</span>
                    <span class="fx__score fx__score--empty">v</span>
                    <span class="fx__away">${f.away_team}</span>
                  </div></td>
                  <td class="ctr">${hasResult(f)
                    ? html`<span class="fx__score">${f.home_score} – ${f.away_score}</span>`
                    : html`<span class="pill">to play</span>`}</td>
                  <td class="muted" style="font-size:12.5px">${fmtDateTime(f.kickoff)}</td>
                  <td class="num mono">${hasResult(f) ? exacts : "—"}</td>
                </tr>`;
              }).join(""))}
            </tbody>
          </table>
        </div>
      </div>

      <div class="card">
        <div class="card__head">
          <h3>Everyone's week</h3>
          <span class="muted" style="font-size:12.5px">⚡ marks each player's banker (double points)</span>
        </div>
        <div class="card__body card__body--flush table-wrap">
          <table class="tbl pgrid">
            <thead><tr>
              <th class="sticky-col">#</th>
              <th class="sticky-col" style="left:44px;min-width:170px">Entrant</th>
              ${raw(fixtures.map((f) => `<th class="pgrid__fx ctr">${f.home_team}<small>v ${f.away_team}</small>
                ${hasResult(f) ? `<small class="mono" style="color:var(--text-secondary)">${f.home_score}–${f.away_score}</small>` : `<small>—</small>`}</th>`).join(""))}
              <th class="num">Week</th>
            </tr></thead>
            <tbody>
              ${raw(rows.map((r) => html`
                <tr class="${me && r.entrantId === String(me.id) ? "is-me" : ""}">
                  <td class="sticky-col"><span class="${rankClass(r.rank)}">${r.rank}${r.tied ? "=" : ""}</span></td>
                  <td class="sticky-col" style="left:44px">
                    <div class="who"><span class="who__name">${r.name}</span><span class="who__team">${r.team || ""}</span></div>
                  </td>
                  ${raw(fixtures.map((f) => {
                    const p = idx.get(`${f.id}|${r.entrantId}`);
                    const res = tal.cells.get(`${f.id}|${r.entrantId}`);
                    return html`<td class="ctr pgrid__cell">
                      <div style="display:grid;gap:3px;justify-items:center">
                        <span class="mono" style="font-size:12.5px">${p ? `${p.home_score}–${p.away_score}` : "—"}${p?.is_bonus ? " ⚡" : ""}</span>
                        ${ptsChip(res)}
                      </div></td>`;
                  }).join(""))}
                  <td class="num"><span class="pts pts--total">${r.points > 0 ? "+" : ""}${r.points}</span></td>
                </tr>`).join(""))}
            </tbody>
          </table>
        </div>
      </div>
    </div>`;

    qs("#gwsel", host).addEventListener("change", (e) => { gw = Number(e.target.value); paint(); });
    qs("#prev", host).addEventListener("click", () => { gw = tal.gameweeks[Math.max(0, pos - 1)]; paint(); });
    qs("#next", host).addEventListener("click", () => { gw = tal.gameweeks[Math.min(tal.gameweeks.length - 1, pos + 1)]; paint(); });
    qs("#csv", host).addEventListener("click", () => {
      const head = ["Rank", "Full name", "Team", ...fixtures.map((f) => `${f.home_team} v ${f.away_team}`), "Week points"];
      const body = rows.map((r) => [
        r.rank, r.name, r.team,
        ...fixtures.map((f) => {
          const p = idx.get(`${f.id}|${r.entrantId}`);
          const res = tal.cells.get(`${f.id}|${r.entrantId}`);
          return p ? `${p.home_score}-${p.away_score}${p.is_bonus ? " (B)" : ""}${res && res.kind !== "pending" ? ` = ${res.points}` : ""}` : "";
        }),
        r.points,
      ]);
      downloadCsv(`${state.league.name} — GW${gw}.csv`, [head, ...body]);
    });
  };

  paint();
}
