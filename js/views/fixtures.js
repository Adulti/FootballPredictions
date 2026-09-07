import {
  html, raw, icon, qs, qsa, on, toast, openModal, closeModal, confirmModal,
  emptyState, fmtDateTime, toLocalInput, downloadCsv, parseCsv,
} from "../lib/ui.js";
import { state, api } from "../lib/store.js";
import { derived, fixturesFor } from "../lib/derive.js";
import { hasResult } from "../lib/scoring.js";
import { invalidate } from "../lib/derive.js";

export const title = "Fixtures";

export async function render(host, ctx) {
  const { tal } = derived();
  const gws = tal.gameweeks;

  host.innerHTML = html`
  <div class="stack">
    <div class="row">
      <button class="btn btn--primary" id="add-gw">${icon("plus", 16)} Add gameweek</button>
      <button class="btn" id="add-one">${icon("plus", 15)} Single fixture</button>
      <div class="spacer"></div>
      <span class="pill">${state.fixtures.length} fixtures · ${state.fixtures.filter(hasResult).length} scored</span>
      <button class="btn btn--sm" id="csv">${icon("download", 15)} Export</button>
    </div>

    <div class="banner banner--info">
      ${icon("zap", 15)}
      <span>Scores save the moment you type them — tables, weekly results and history all update straight away.</span>
    </div>

    ${gws.length ? raw(gws.map((gw) => {
      const fx = fixturesFor(gw);
      const done = fx.filter(hasResult).length;
      return html`
      <div class="card">
        <div class="card__head">
          <h3>Gameweek ${gw}</h3>
          <span class="pill ${done === fx.length ? "pill--good" : done ? "pill--warn" : ""}">${done}/${fx.length} results in</span>
          <div class="spacer"></div>
          <a class="btn btn--sm" href="#/predictions/${gw}">${icon("edit", 14)} Predictions</a>
          <a class="btn btn--sm btn--ghost" href="#/weeks/${gw}">${icon("chart", 14)} Results</a>
          <button class="btn btn--sm btn--danger" data-del-gw="${gw}" title="Delete this whole gameweek">${icon("trash", 14)}</button>
        </div>
        <div class="card__body card__body--flush table-wrap">
          <table class="tbl">
            <thead><tr>
              <th>Home</th><th class="ctr">Score</th><th>Away</th>
              <th>Kick-off</th><th class="num">Predictions</th><th></th>
            </tr></thead>
            <tbody>
              ${raw(fx.map((f) => {
                const preds = state.predictions.filter((p) => p.fixture_id === f.id).length;
                return html`<tr>
                  <td style="text-align:right"><b>${f.home_team}</b></td>
                  <td class="ctr">
                    <span class="scorebox">
                      <input class="input input--num" data-score="${f.id}" data-side="home" type="number" min="0" max="99"
                             value="${f.home_score ?? ""}" aria-label="${f.home_team} score" placeholder="–" />
                      <span>–</span>
                      <input class="input input--num" data-score="${f.id}" data-side="away" type="number" min="0" max="99"
                             value="${f.away_score ?? ""}" aria-label="${f.away_team} score" placeholder="–" />
                    </span>
                  </td>
                  <td><b>${f.away_team}</b></td>
                  <td class="muted" style="font-size:12.5px">${fmtDateTime(f.kickoff)}</td>
                  <td class="num mono">${preds}/${state.entrants.length}</td>
                  <td class="num" style="white-space:nowrap">
                    ${hasResult(f) ? html`<button class="btn btn--sm btn--ghost" data-clear="${f.id}" title="Clear result">${icon("x", 14)}</button>` : ""}
                    <button class="btn btn--sm btn--ghost" data-edit="${f.id}" title="Edit fixture">${icon("edit", 14)}</button>
                    <button class="btn btn--sm btn--ghost" data-del="${f.id}" title="Delete fixture">${icon("trash", 14)}</button>
                  </td>
                </tr>`;
              }).join(""))}
            </tbody>
          </table>
        </div>
      </div>`;
    }).join("")) : raw(emptyState({
      mark: "📅", title: "No fixtures yet",
      body: "Add a gameweek and paste the fixtures in — one per line, like “Arsenal v Chelsea”.",
      action: `<div class="row" style="justify-content:center"><button class="btn btn--primary" id="add-gw2">Add the first gameweek</button></div>`,
    }))}
  </div>`;

  const reload = () => ctx.rerender({ reload: true });

  /* ---- inline score entry (auto-save, no re-render so focus is kept) ---- */
  const saveScore = async (id, side, value) => {
    const v = value === "" ? null : Math.max(0, Math.min(99, Number(value)));
    const patch = side === "home" ? { home_score: v } : { away_score: v };
    const fx = state.fixtures.find((f) => String(f.id) === String(id));
    try {
      await api.updateFixture(fx.id, patch);
      Object.assign(fx, patch);
      invalidate();
      const row = qs(`[data-score="${id}"]`, host)?.closest("tr");
      if (row) {
        const cell = row.querySelector(".num.mono");
        if (cell) cell.classList.add("saved");
      }
      toast(`${fx.home_team} ${fx.home_score ?? "–"}–${fx.away_score ?? "–"} ${fx.away_team}`, "good");
    } catch (ex) { toast(ex.message, "bad"); }
  };

  on(host, "change", "[data-score]", (e, el) => saveScore(el.dataset.score, el.dataset.side, el.value));
  on(host, "keydown", "[data-score]", (e, el) => {
    if (e.key === "Enter") {
      el.blur();
      const all = qsa("[data-score]", host);
      const next = all[all.indexOf(el) + 1];
      if (next) { next.focus(); next.select?.(); }
    }
  });

  on(host, "click", "[data-clear]", async (e, el) => {
    const fx = state.fixtures.find((f) => String(f.id) === el.dataset.clear);
    await api.updateFixture(fx.id, { home_score: null, away_score: null });
    toast("Result cleared", "good");
    await reload();
  });

  /* ---- add / edit ---- */
  const fixtureForm = (fx) => openModal({
    title: fx ? "Edit fixture" : "Add fixture",
    body: html`
      <div class="grid" style="grid-template-columns:1fr 1fr;gap:12px">
        <div class="field"><label for="x-home">Home team</label>
          <input class="input" id="x-home" value="${fx?.home_team || ""}" placeholder="Arsenal" /></div>
        <div class="field"><label for="x-away">Away team</label>
          <input class="input" id="x-away" value="${fx?.away_team || ""}" placeholder="Chelsea" /></div>
        <div class="field"><label for="x-gw">Gameweek</label>
          <input class="input" id="x-gw" type="number" min="1" value="${fx?.gameweek || nextGwNumber()}" /></div>
        <div class="field"><label for="x-ko">Kick-off</label>
          <input class="input" id="x-ko" type="datetime-local" value="${toLocalInput(fx?.kickoff)}" /></div>
      </div>`,
    footer: html`<button class="btn" data-close>Cancel</button>
                 <button class="btn btn--primary" id="x-save">${fx ? "Save changes" : "Add fixture"}</button>`,
    onMount(root) {
      qs("#x-save", root).addEventListener("click", async () => {
        const payload = {
          home_team: qs("#x-home", root).value.trim(),
          away_team: qs("#x-away", root).value.trim(),
          gameweek: Number(qs("#x-gw", root).value) || 1,
          kickoff: qs("#x-ko", root).value ? new Date(qs("#x-ko", root).value).toISOString() : null,
        };
        if (!payload.home_team || !payload.away_team) { toast("Both teams are required", "bad"); return; }
        qs("#x-save", root).disabled = true;
        try {
          if (fx) await api.updateFixture(fx.id, payload);
          else await api.addFixtures([payload]);
          closeModal(); toast(fx ? "Fixture updated" : "Fixture added", "good");
          await reload();
        } catch (ex) { qs("#x-save", root).disabled = false; toast(ex.message, "bad"); }
      });
    },
  });

  qs("#add-one", host)?.addEventListener("click", () => fixtureForm(null));
  on(host, "click", "[data-edit]", (e, el) =>
    fixtureForm(state.fixtures.find((f) => String(f.id) === el.dataset.edit)));

  on(host, "click", "[data-del]", (e, el) => {
    const fx = state.fixtures.find((f) => String(f.id) === el.dataset.del);
    confirmModal({
      title: "Delete fixture",
      message: `Delete ${fx.home_team} v ${fx.away_team}? Every prediction for it goes too.`,
      async onConfirm() { await api.deleteFixtures([fx.id]); toast("Fixture deleted", "good"); await reload(); },
    });
  });

  on(host, "click", "[data-del-gw]", (e, el) => {
    const gw = Number(el.dataset.delGw);
    const ids = fixturesFor(gw).map((f) => f.id);
    confirmModal({
      title: `Delete gameweek ${gw}`,
      message: `This removes ${ids.length} fixtures and every prediction attached to them.`,
      confirmLabel: "Delete gameweek",
      async onConfirm() { await api.deleteFixtures(ids); toast(`Gameweek ${gw} deleted`, "good"); await reload(); },
    });
  });

  /* ---- bulk gameweek ---- */
  const bulk = () => openModal({
    title: "Add a gameweek",
    wide: true,
    body: html`
      <div class="grid" style="grid-template-columns:1fr 1fr;gap:12px">
        <div class="field"><label for="g-num">Gameweek number</label>
          <input class="input" id="g-num" type="number" min="1" value="${nextGwNumber()}" /></div>
        <div class="field"><label for="g-ko">Kick-off for all (optional)</label>
          <input class="input" id="g-ko" type="datetime-local" /></div>
      </div>
      <div class="field">
        <label for="g-text">Fixtures — one per line</label>
        <textarea class="input" id="g-text" rows="11" style="font-family:var(--mono);font-size:12.5px"
          placeholder="Arsenal v Chelsea&#10;Liverpool vs Man City&#10;Everton - Spurs&#10;Brighton,Fulham"></textarea>
        <span class="hint">Separate the teams with <code>v</code>, <code>vs</code>, <code>-</code> or a comma. Add a score to record the result at the same time: <code>Arsenal 2-1 Chelsea</code>.</span>
      </div>
      <div class="field">
        <label for="g-file">…or import a CSV</label>
        <input class="input" id="g-file" type="file" accept=".csv,text/csv" />
        <span class="hint">Columns: <code>gameweek, home_team, away_team, kickoff, home_score, away_score</code>.</span>
      </div>
      <div id="g-preview"></div>`,
    footer: html`<button class="btn" data-close>Cancel</button>
                 <button class="btn btn--primary" id="g-save" disabled>Add fixtures</button>`,
    onMount(root) {
      let rows = [];
      const saveBtn = qs("#g-save", root);
      const preview = qs("#g-preview", root);

      const setRows = (r) => {
        rows = r;
        saveBtn.disabled = !r.length;
        saveBtn.textContent = r.length ? `Add ${r.length} fixture${r.length === 1 ? "" : "s"}` : "Add fixtures";
        preview.innerHTML = r.length ? html`
          <div class="table-wrap" style="max-height:230px;overflow:auto">
            <table class="tbl"><thead><tr><th>GW</th><th>Home</th><th class="ctr">Score</th><th>Away</th></tr></thead>
            <tbody>${raw(r.map((x) => `<tr><td class="mono">${x.gameweek}</td><td>${x.home_team}</td>
              <td class="ctr mono">${x.home_score ?? "–"}–${x.away_score ?? "–"}</td><td>${x.away_team}</td></tr>`).join(""))}
            </tbody></table></div>` : "";
      };

      const parseLines = () => {
        const gw = Number(qs("#g-num", root).value) || 1;
        const koVal = qs("#g-ko", root).value;
        const kickoff = koVal ? new Date(koVal).toISOString() : null;
        const out = [];
        for (const line of qs("#g-text", root).value.split(/\r?\n/)) {
          const t = line.trim();
          if (!t) continue;
          // "Home 2-1 Away"
          let m = t.match(/^(.+?)\s+(\d{1,2})\s*[-–:]\s*(\d{1,2})\s+(.+)$/);
          if (m) { out.push({ gameweek: gw, home_team: m[1].trim(), away_team: m[4].trim(), home_score: +m[2], away_score: +m[3], kickoff }); continue; }
          m = t.split(/\s+vs?\.?\s+|\s+-\s+|\s*,\s*|\s+@\s+/i);
          if (m.length >= 2 && m[0].trim() && m[1].trim()) {
            out.push({ gameweek: gw, home_team: m[0].trim(), away_team: m[1].trim(), home_score: null, away_score: null, kickoff });
          }
        }
        return out;
      };

      qs("#g-text", root).addEventListener("input", () => setRows(parseLines()));
      qs("#g-num", root).addEventListener("input", () => setRows(parseLines()));
      qs("#g-ko", root).addEventListener("input", () => setRows(parseLines()));

      qs("#g-file", root).addEventListener("change", async (e) => {
        const file = e.target.files[0];
        if (!file) return;
        const grid = parseCsv(await file.text());
        if (!grid.length) return;
        const head = grid[0].map((h) => h.trim().toLowerCase());
        const hasHeader = head.includes("home_team") || head.includes("home");
        const col = (name, alt) => {
          const i = head.indexOf(name);
          return i > -1 ? i : head.indexOf(alt);
        };
        const iGw = hasHeader ? col("gameweek", "gw") : 0;
        const iH = hasHeader ? col("home_team", "home") : 1;
        const iA = hasHeader ? col("away_team", "away") : 2;
        const iKo = hasHeader ? col("kickoff", "date") : 3;
        const iHs = hasHeader ? col("home_score", "hs") : 4;
        const iAs = hasHeader ? col("away_score", "as") : 5;
        const body = hasHeader ? grid.slice(1) : grid;
        const num = (v) => (v === undefined || v === null || String(v).trim() === "" ? null : Number(v));
        setRows(body.filter((r) => r[iH]?.trim() && r[iA]?.trim()).map((r) => ({
          gameweek: num(r[iGw]) || Number(qs("#g-num", root).value) || 1,
          home_team: r[iH].trim(), away_team: r[iA].trim(),
          kickoff: iKo > -1 && r[iKo] ? new Date(r[iKo]).toISOString() : null,
          home_score: iHs > -1 ? num(r[iHs]) : null,
          away_score: iAs > -1 ? num(r[iAs]) : null,
        })));
      });

      saveBtn.addEventListener("click", async () => {
        saveBtn.disabled = true;
        try {
          await api.addFixtures(rows);
          closeModal(); toast(`${rows.length} fixtures added`, "good");
          await reload();
        } catch (ex) { saveBtn.disabled = false; toast(ex.message, "bad"); }
      });
    },
  });

  qs("#add-gw", host)?.addEventListener("click", bulk);
  qs("#add-gw2", host)?.addEventListener("click", bulk);

  qs("#csv", host)?.addEventListener("click", () => {
    downloadCsv(`${state.league.name} — fixtures.csv`, [
      ["gameweek", "home_team", "away_team", "kickoff", "home_score", "away_score"],
      ...[...state.fixtures].sort((a, b) => a.gameweek - b.gameweek)
        .map((f) => [f.gameweek, f.home_team, f.away_team, f.kickoff || "", f.home_score ?? "", f.away_score ?? ""]),
    ]);
  });
}

function nextGwNumber() {
  const gws = state.fixtures.map((f) => Number(f.gameweek));
  return gws.length ? Math.max(...gws) + 1 : 1;
}
