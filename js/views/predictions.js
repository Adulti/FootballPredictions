import {
  html, raw, icon, qs, qsa, on, toast, openModal, closeModal, emptyState, initials,
  syncScrollbars,
} from "../lib/ui.js";
import { state, api } from "../lib/store.js";
import { derived, fixturesFor, predIndex, nextOpenGw, latestCompletedGw } from "../lib/derive.js";
import { hasResult, scorePrediction, KIND_LABELS } from "../lib/scoring.js";
import { parseHash, navigate } from "../lib/router.js";

export const title = "Predictions";

export async function render(host, ctx) {
  const { tal, rules } = derived();

  if (!state.entrants.length || !tal.gameweeks.length) {
    host.innerHTML = emptyState({
      mark: "✍️", title: "Nothing to predict yet",
      body: "You need at least one entrant and one gameweek of fixtures before predictions can be entered.",
      action: `<div class="row" style="justify-content:center">
        <a class="btn" href="#/entrants">Add entrants</a>
        <a class="btn btn--primary" href="#/fixtures">Add fixtures</a></div>`,
    });
    return;
  }

  const fromHash = Number(parseHash().params[0]);
  let gw = tal.gameweeks.includes(fromHash) ? fromHash : (nextOpenGw() ?? latestCompletedGw() ?? tal.gameweeks[0]);

  /** edits: `${fxId}|${entId}` -> {home, away, bonus} */
  let edits = new Map();
  let dirtyEntrants = new Set();

  const paint = () => {
    const fixtures = fixturesFor(gw);
    const idx = predIndex();
    edits = new Map();
    dirtyEntrants = new Set();

    const cellValue = (fxId, entId) => {
      const p = idx.get(`${fxId}|${entId}`);
      return {
        home: p?.home_score ?? "", away: p?.away_score ?? "", bonus: !!p?.is_bonus,
        existed: !!p, id: p?.id,
      };
    };

    host.innerHTML = html`
    <div class="stack">
      <div class="row">
        <div class="field" style="min-width:180px">
          <label class="sr-only" for="gwsel">Gameweek</label>
          <select class="select" id="gwsel">
            ${raw(tal.gameweeks.map((g) => `<option value="${g}" ${g === gw ? "selected" : ""}>Gameweek ${g}${tal.completedGameweeks.includes(g) ? " · played" : ""}</option>`).join(""))}
          </select>
        </div>
        <button class="btn" id="one-by-one">${icon("users", 15)} Enter for one person</button>
        <div class="spacer"></div>
        <span class="pill" id="dirty-pill" hidden>${icon("zap", 13)} <span id="dirty-count">0</span> unsaved</span>
        <button class="btn btn--primary" id="save" disabled>${icon("check", 16)} Save predictions</button>
      </div>

      <div class="banner banner--info">
        ${icon("zap", 15)}
        <span>Type each score, then click the ⚡ to mark that person's <b>banker</b> — one fixture per week, worth ×${rules.bonusMultiplier}.
        <kbd>Enter</kbd> jumps down the column, so you can do one fixture for everyone at a time.</span>
      </div>

      <div class="card">
        <div class="card__head">
          <h3>Gameweek ${gw} predictions</h3>
          <span class="pill">${state.entrants.length} entrants × ${fixtures.length} fixtures</span>
          ${tal.completedGameweeks.includes(gw) ? html`<span class="pill pill--warn">Results already entered — edits will re-score the week</span>` : ""}
        </div>
        <div class="card__body card__body--flush table-wrap" id="pgrid-scroll">
          <table class="tbl pgrid">
            <thead><tr>
              <th class="sticky-col" style="min-width:180px">Entrant</th>
              ${raw(fixtures.map((f) => `<th class="pgrid__fx ctr">
                ${f.home_team}<small>v ${f.away_team}</small>
                ${hasResult(f) ? `<small class="mono" style="color:var(--text-secondary)">result ${f.home_score}–${f.away_score}</small>` : ""}
              </th>`).join(""))}
              <th class="num">Week pts</th>
            </tr></thead>
            <tbody>
              ${raw(state.entrants.map((e) => {
                const weekPts = tal.byGw.get(gw)?.get(String(e.id))?.points ?? 0;
                return html`<tr data-ent="${e.id}">
                  <td class="sticky-col">
                    <div class="row" style="gap:8px;flex-wrap:nowrap">
                      <div class="avatar" style="width:26px;height:26px;font-size:10px">${initials(e.full_name)}</div>
                      <div class="who"><span class="who__name">${e.full_name}</span><span class="who__team">${e.team_name || ""}</span></div>
                    </div>
                  </td>
                  ${raw(fixtures.map((f) => {
                    const v = cellValue(f.id, e.id);
                    const res = tal.cells.get(`${f.id}|${e.id}`);
                    return html`<td class="ctr pgrid__cell" data-cellwrap="${f.id}|${e.id}">
                      <div style="display:grid;gap:4px;justify-items:center">
                        <span class="scorebox">
                          <input class="input input--num" type="number" min="0" max="99" placeholder="–"
                                 data-cell="${f.id}|${e.id}" data-side="home" data-fx="${f.id}" value="${v.home}"
                                 aria-label="${e.full_name} — ${f.home_team} goals" />
                          <span>–</span>
                          <input class="input input--num" type="number" min="0" max="99" placeholder="–"
                                 data-cell="${f.id}|${e.id}" data-side="away" data-fx="${f.id}" value="${v.away}"
                                 aria-label="${e.full_name} — ${f.away_team} goals" />
                          <button class="bonus-btn ${v.bonus ? "is-on" : ""}" data-bonus="${f.id}|${e.id}"
                                  title="Mark as ${e.full_name}'s banker (×${rules.bonusMultiplier})" aria-pressed="${v.bonus}">⚡</button>
                        </span>
                        <span class="cell-pts">${res && res.kind !== "pending" && (res.kind !== "none" || res.points)
                          ? html`<span class="pts pts--${res.kind === "none" ? "wrong" : res.kind}" title="${KIND_LABELS[res.kind]}">${res.points > 0 ? "+" : ""}${res.points}</span>`
                          : ""}</span>
                      </div>
                    </td>`;
                  }).join(""))}
                  <td class="num"><span class="pts pts--total" data-week-total="${e.id}">${weekPts > 0 ? "+" : ""}${weekPts}</span></td>
                </tr>`;
              }).join(""))}
            </tbody>
          </table>
        </div>
      </div>
    </div>`;

    /* The grid is wider than any screen — mirror its scrollbar above it too. */
    syncScrollbars(qs("#pgrid-scroll", host));

    /* ---------- editing ---------- */
    const markDirty = (entId) => {
      dirtyEntrants.add(String(entId));
      const pill = qs("#dirty-pill", host);
      pill.hidden = false;
      qs("#dirty-count", host).textContent = String(dirtyEntrants.size);
      qs("#save", host).disabled = false;
    };

    const readCell = (key) => {
      const [h, a] = ["home", "away"].map((side) => qs(`[data-cell="${key}"][data-side="${side}"]`, host));
      const bonus = qs(`[data-bonus="${key}"]`, host)?.classList.contains("is-on");
      return { home: h.value, away: a.value, bonus };
    };

    on(host, "input", "[data-cell]", (e, el) => {
      const [, entId] = el.dataset.cell.split("|");
      const n = Number(el.value);
      if (el.value !== "" && (!Number.isFinite(n) || n < 0)) el.value = "";
      if (el.value !== "" && n > 99) el.value = "99";
      edits.set(el.dataset.cell, readCell(el.dataset.cell));
      markDirty(entId);
    });

    /* Enter → next entrant, same fixture (fill a column) */
    on(host, "keydown", "[data-cell]", (e, el) => {
      if (e.key !== "Enter") return;
      e.preventDefault();
      const same = qsa(`[data-fx="${el.dataset.fx}"][data-side="${el.dataset.side}"]`, host);
      const next = same[same.indexOf(el) + 1] || same[0];
      next.focus(); next.select();
    });

    on(host, "click", "[data-bonus]", (e, el) => {
      const key = el.dataset.bonus;
      const [, entId] = key.split("|");
      const on_ = !el.classList.contains("is-on");
      // one banker per entrant per gameweek
      qsa(`[data-bonus$="|${entId}"]`, host).forEach((b) => {
        b.classList.remove("is-on"); b.setAttribute("aria-pressed", "false");
        edits.set(b.dataset.bonus, readCell(b.dataset.bonus));
      });
      if (on_) { el.classList.add("is-on"); el.setAttribute("aria-pressed", "true"); }
      qsa(`[data-bonus$="|${entId}"]`, host).forEach((b) => edits.set(b.dataset.bonus, readCell(b.dataset.bonus)));
      markDirty(entId);
    });

    /* ---------- save ---------- */
    qs("#save", host).addEventListener("click", async () => {
      const btn = qs("#save", host);
      btn.disabled = true; btn.textContent = "Saving…";
      try {
        const upserts = [];
        const deletes = [];
        for (const entId of dirtyEntrants) {
          for (const f of fixtures) {
            const key = `${f.id}|${entId}`;
            const cur = edits.get(key) || readCell(key);
            const existing = idx.get(key);
            const empty = cur.home === "" || cur.away === "";
            if (empty) { if (existing) deletes.push(existing.id); continue; }
            upserts.push({
              fixture_id: f.id, entrant_id: entId,
              home_score: Number(cur.home), away_score: Number(cur.away),
              is_bonus: !!cur.bonus,
            });
          }
        }
        if (deletes.length) await api.deletePredictions(deletes);
        if (upserts.length) await api.savePredictions(upserts);
        toast(`Saved ${upserts.length} prediction${upserts.length === 1 ? "" : "s"}`, "good");
        await ctx.rerender({ reload: true });
      } catch (ex) {
        btn.disabled = false; btn.innerHTML = "Save predictions";
        toast(ex.message, "bad");
      }
    });

    qs("#gwsel", host).addEventListener("change", (e) => {
      if (dirtyEntrants.size && !confirm("You have unsaved predictions. Switch gameweek and lose them?")) {
        e.target.value = String(gw); return;
      }
      gw = Number(e.target.value);
      navigate("predictions", gw);
    });

    qs("#one-by-one", host).addEventListener("click", () => onePersonModal(gw, fixtures, idx, ctx, rules));

    window.onbeforeunload = dirtyEntrants.size ? () => "" : null;
  };

  paint();
}

/* ==========================================================================
   "Enter for one person" — a focused single-column form, handy on a phone
   ========================================================================== */
function onePersonModal(gw, fixtures, idx, ctx, rules) {
  const first = state.entrants[0];
  openModal({
    title: `Gameweek ${gw} — single entrant`,
    wide: true,
    body: html`
      <div class="field">
        <label for="op-ent">Entrant</label>
        <select class="select" id="op-ent">
          ${raw(state.entrants.map((e) => `<option value="${e.id}">${e.full_name}${e.team_name ? ` — ${e.team_name}` : ""}</option>`).join(""))}
        </select>
      </div>
      <div id="op-rows" class="stack stack--sm"></div>`,
    footer: html`<button class="btn" data-close>Cancel</button>
                 <button class="btn btn--primary" id="op-save">Save this entrant</button>`,
    onMount(root) {
      const rowsHost = qs("#op-rows", root);
      const sel = qs("#op-ent", root);

      const draw = () => {
        const entId = sel.value;
        rowsHost.innerHTML = fixtures.map((f) => {
          const p = idx.get(`${f.id}|${entId}`);
          return html`
          <div class="row" style="gap:10px;padding:7px 0;border-bottom:1px solid var(--border)">
            <div class="fx" style="flex:1;min-width:0">
              <span class="fx__home">${f.home_team}</span>
              <span class="fx__score fx__score--empty">v</span>
              <span class="fx__away">${f.away_team}</span>
            </div>
            <span class="scorebox">
              <input class="input input--num" type="number" min="0" max="99" placeholder="–"
                     data-op="${f.id}" data-side="home" value="${p?.home_score ?? ""}" aria-label="${f.home_team} goals" />
              <span>–</span>
              <input class="input input--num" type="number" min="0" max="99" placeholder="–"
                     data-op="${f.id}" data-side="away" value="${p?.away_score ?? ""}" aria-label="${f.away_team} goals" />
              <button class="bonus-btn ${p?.is_bonus ? "is-on" : ""}" data-opbonus="${f.id}"
                      title="Banker (×${rules.bonusMultiplier})" aria-pressed="${!!p?.is_bonus}">⚡</button>
            </span>
          </div>`;
        }).join("");
      };
      draw();
      sel.addEventListener("change", draw);

      on(root, "click", "[data-opbonus]", (e, el) => {
        const was = el.classList.contains("is-on");
        qsa("[data-opbonus]", root).forEach((b) => { b.classList.remove("is-on"); b.setAttribute("aria-pressed", "false"); });
        if (!was) { el.classList.add("is-on"); el.setAttribute("aria-pressed", "true"); }
      });

      qs("#op-save", root).addEventListener("click", async () => {
        const btn = qs("#op-save", root);
        btn.disabled = true;
        const entId = sel.value;
        const upserts = [], deletes = [];
        for (const f of fixtures) {
          const h = qs(`[data-op="${f.id}"][data-side="home"]`, root).value;
          const a = qs(`[data-op="${f.id}"][data-side="away"]`, root).value;
          const bonus = qs(`[data-opbonus="${f.id}"]`, root).classList.contains("is-on");
          const existing = idx.get(`${f.id}|${entId}`);
          if (h === "" || a === "") { if (existing) deletes.push(existing.id); continue; }
          upserts.push({ fixture_id: f.id, entrant_id: entId, home_score: Number(h), away_score: Number(a), is_bonus: bonus });
        }
        try {
          if (deletes.length) await api.deletePredictions(deletes);
          if (upserts.length) await api.savePredictions(upserts);
          closeModal();
          toast("Predictions saved", "good");
          await ctx.rerender({ reload: true });
        } catch (ex) { btn.disabled = false; toast(ex.message, "bad"); }
      });
    },
  });
}
