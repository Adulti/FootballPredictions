import {
  html, raw, icon, qs, on, toast, confirmModal, copyText, downloadCsv, initials,
} from "../lib/ui.js";
import { state, api, isDemo, makeJoinCode, refreshLeagues, selectLeague } from "../lib/store.js";
import { derived, invalidate } from "../lib/derive.js";
import { DEFAULT_RULES } from "../lib/scoring.js";

export const title = "Settings";

export async function render(host, ctx) {
  const L = state.league;
  const rules = { ...DEFAULT_RULES, ...(L.rules || {}) };
  const { tal } = derived();

  host.innerHTML = html`
  <div class="stack">
    <div class="card">
      <div class="card__head"><h3>League details</h3></div>
      <div class="card__body stack stack--sm">
        <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px">
          <div class="field"><label for="s-name">League name</label>
            <input class="input" id="s-name" value="${L.name}" /></div>
          <div class="field"><label for="s-season">Season</label>
            <input class="input" id="s-season" value="${L.season || ""}" placeholder="2025/26" /></div>
        </div>
        <div class="row">
          <div class="field" style="flex:1;min-width:200px">
            <label>Join code</label>
            <div class="row" style="gap:6px">
              <code class="mono" style="padding:8px 12px;background:var(--surface-2);border:1px solid var(--border);border-radius:8px;font-weight:600;letter-spacing:.12em">${L.join_code || "—"}</code>
              <button class="btn btn--sm" id="s-copy">${icon("copy", 14)} Copy</button>
              <button class="btn btn--sm btn--ghost" id="s-regen" title="Generate a new code — the old one stops working">${icon("swap", 14)} New code</button>
            </div>
            <span class="hint">Anyone with this code can join as a viewer.</span>
          </div>
        </div>
        <div class="row row--end"><button class="btn btn--primary" id="s-save">${icon("check", 15)} Save details</button></div>
      </div>
    </div>

    <div class="card">
      <div class="card__head">
        <h3>Scoring rules</h3>
        <span class="muted" style="font-size:12.5px">Changing these re-scores every gameweek instantly</span>
      </div>
      <div class="card__body stack stack--sm">
        <div class="grid grid--form">
          ${raw([
            ["r-exact", "Exact score", rules.exact, "Both scores right"],
            ["r-gd", "Goal difference", rules.gd, "Right margin, wrong scores"],
            ["r-outcome", "Outcome", rules.outcome, "Right winner or a draw"],
            ["r-wrong", "Wrong", rules.wrong, "Everything else"],
            ["r-missed", "No prediction", rules.missed, "Nothing submitted for a played fixture"],
            ["r-mult", "Banker multiplier", rules.bonusMultiplier, "Applied to the chosen fixture"],
          ].map(([id, label, val, hint]) => html`
            <div class="field">
              <label for="${id}">${label}</label>
              <input class="input input--num" id="${id}" type="number" step="1" value="${val}" />
              <span class="hint">${hint}</span>
            </div>`).join(""))}
        </div>
        <label class="row" style="gap:8px;cursor:pointer">
          <input type="checkbox" id="r-neg" ${rules.bonusAppliesToNegatives ? "checked" : ""} />
          <span>Banker also multiplies a losing prediction <span class="muted">(a wrong banker costs ${rules.wrong * rules.bonusMultiplier} instead of ${rules.wrong})</span></span>
        </label>
        <div class="row">
          <button class="btn btn--ghost btn--sm" id="r-reset">Reset to defaults</button>
          <div class="spacer"></div>
          <button class="btn btn--primary" id="r-save">${icon("check", 15)} Save scoring</button>
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card__head">
        <h3>Members</h3>
        <span class="pill">${state.members.length}</span>
      </div>
      <div class="card__body card__body--flush table-wrap">
        <table class="tbl">
          <thead><tr><th>Person</th><th>Role</th><th>Linked entrant</th><th></th></tr></thead>
          <tbody>
            ${raw(state.members.map((m) => {
              const ent = state.entrants.find((e) => e.user_id === m.user_id);
              const isOwner = m.user_id === L.owner_id;
              return html`<tr>
                <td><div class="row" style="gap:9px;flex-wrap:nowrap">
                  <div class="avatar">${initials(m.display_name)}</div>
                  <div class="who"><span class="who__name">${m.display_name}</span><span class="who__team">${m.email || ""}</span></div>
                </div></td>
                <td>${isOwner ? html`<span class="pill pill--accent">Owner</span>` : html`
                  <select class="select" data-role="${m.id}" style="min-height:30px;padding:3px 26px 3px 9px;font-size:12.5px">
                    <option value="admin" ${m.role === "admin" ? "selected" : ""}>Admin</option>
                    <option value="viewer" ${m.role === "viewer" ? "selected" : ""}>Viewer</option>
                  </select>`}</td>
                <td>${ent ? html`<span class="pill">${ent.full_name}</span>` : html`<span class="muted" style="font-size:12.5px">—</span>`}</td>
                <td class="num">${isOwner ? "" : html`<button class="btn btn--sm btn--ghost" data-kick="${m.id}" title="Remove member">${icon("trash", 14)}</button>`}</td>
              </tr>`;
            }).join(""))}
          </tbody>
        </table>
      </div>
    </div>

    <div class="card">
      <div class="card__head"><h3>Data</h3></div>
      <div class="card__body stack stack--sm">
        <p class="muted" style="font-size:12.5px">
          ${state.entrants.length} entrants · ${state.fixtures.length} fixtures · ${state.predictions.length} predictions ·
          ${tal.completedGameweeks.length} of ${tal.gameweeks.length} gameweeks played
        </p>
        <div class="row">
          <button class="btn btn--sm" id="d-json">${icon("download", 14)} Full backup (JSON)</button>
          <button class="btn btn--sm" id="d-preds">${icon("download", 14)} All predictions (CSV)</button>
        </div>
      </div>
    </div>

    <div class="card" style="border-color:color-mix(in srgb, var(--bad) 40%, transparent)">
      <div class="card__head"><h3 style="color:var(--bad)">Danger zone</h3></div>
      <div class="card__body stack stack--sm">
        <div class="row">
          <div>
            <div style="font-weight:600">Clear all results</div>
            <div class="muted" style="font-size:12.5px">Wipes every score but keeps fixtures and predictions.</div>
          </div>
          <div class="spacer"></div>
          <button class="btn btn--danger btn--sm" id="z-results">Clear results</button>
        </div>
        <div class="row" style="border-top:1px solid var(--border);padding-top:10px">
          <div>
            <div style="font-weight:600">Delete this league</div>
            <div class="muted" style="font-size:12.5px">Removes ${L.name} and everything in it, permanently.</div>
          </div>
          <div class="spacer"></div>
          <button class="btn btn--danger btn--sm" id="z-league">Delete league</button>
        </div>
      </div>
    </div>
  </div>`;

  /* ---- details ---- */
  qs("#s-save", host).addEventListener("click", async () => {
    const name = qs("#s-name", host).value.trim();
    if (!name) { toast("A league name is required", "bad"); return; }
    await api.updateLeague({ name, season: qs("#s-season", host).value.trim() });
    toast("League details saved", "good");
    await refreshLeagues();
    await ctx.rerender();
  });
  qs("#s-copy", host).addEventListener("click", () => copyText(L.join_code || ""));
  qs("#s-regen", host).addEventListener("click", () => confirmModal({
    title: "Generate a new join code",
    message: "The current code stops working straight away. People already in the league keep their access.",
    confirmLabel: "Generate new code", danger: false,
    async onConfirm() {
      await api.updateLeague({ join_code: makeJoinCode() });
      toast("New join code generated", "good");
      await ctx.rerender();
    },
  }));

  /* ---- scoring ---- */
  qs("#r-save", host).addEventListener("click", async () => {
    const next = {
      ...rules,
      exact: Number(qs("#r-exact", host).value),
      gd: Number(qs("#r-gd", host).value),
      outcome: Number(qs("#r-outcome", host).value),
      wrong: Number(qs("#r-wrong", host).value),
      missed: Number(qs("#r-missed", host).value),
      bonusMultiplier: Number(qs("#r-mult", host).value),
      bonusAppliesToNegatives: qs("#r-neg", host).checked,
    };
    await api.updateLeague({ rules: next });
    invalidate();
    toast("Scoring updated — tables re-scored", "good");
    await ctx.rerender();
  });
  qs("#r-reset", host).addEventListener("click", async () => {
    await api.updateLeague({ rules: { ...DEFAULT_RULES } });
    invalidate();
    toast("Scoring reset to defaults", "good");
    await ctx.rerender();
  });

  /* ---- members ---- */
  on(host, "change", "[data-role]", async (e, el) => {
    await api.setMemberRole(el.dataset.role, el.value);
    toast("Role updated", "good");
    await ctx.rerender({ reload: true });
  });
  on(host, "click", "[data-kick]", (e, el) => {
    const m = state.members.find((x) => String(x.id) === el.dataset.kick);
    confirmModal({
      title: "Remove member",
      message: `${m.display_name} will lose access to this league.`,
      confirmLabel: "Remove",
      async onConfirm() { await api.removeMember(m.id); toast("Member removed", "good"); await ctx.rerender({ reload: true }); },
    });
  });

  /* ---- data ---- */
  qs("#d-json", host).addEventListener("click", () => {
    const payload = {
      exported_at: new Date().toISOString(),
      league: { name: L.name, season: L.season, rules: L.rules },
      entrants: state.entrants, fixtures: state.fixtures, predictions: state.predictions,
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `${L.name} backup.json`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  });

  qs("#d-preds", host).addEventListener("click", () => {
    const fxById = new Map(state.fixtures.map((f) => [String(f.id), f]));
    const entById = new Map(state.entrants.map((e) => [String(e.id), e]));
    downloadCsv(`${L.name} — predictions.csv`, [
      ["gameweek", "home_team", "away_team", "actual", "entrant", "team_name", "prediction", "banker"],
      ...state.predictions.map((p) => {
        const f = fxById.get(String(p.fixture_id)); const e = entById.get(String(p.entrant_id));
        if (!f || !e) return null;
        return [f.gameweek, f.home_team, f.away_team,
          f.home_score === null ? "" : `${f.home_score}-${f.away_score}`,
          e.full_name, e.team_name, `${p.home_score}-${p.away_score}`, p.is_bonus ? "yes" : ""];
      }).filter(Boolean).sort((a, b) => a[0] - b[0]),
    ]);
  });

  /* ---- danger ---- */
  qs("#z-results", host).addEventListener("click", () => confirmModal({
    title: "Clear all results",
    message: `Removes the scores from all ${state.fixtures.length} fixtures. Predictions are kept.`,
    confirmLabel: "Clear results",
    async onConfirm() {
      for (const f of state.fixtures) {
        if (f.home_score !== null || f.away_score !== null) {
          await api.updateFixture(f.id, { home_score: null, away_score: null });
        }
      }
      invalidate();
      toast("All results cleared", "good");
      await ctx.rerender({ reload: true });
    },
  }));

  qs("#z-league", host).addEventListener("click", () => confirmModal({
    title: `Delete ${L.name}`,
    message: "Entrants, fixtures, predictions and every table snapshot are deleted permanently.",
    confirmLabel: "Delete league",
    async onConfirm() {
      await api.deleteLeague(L.id);
      invalidate();
      await refreshLeagues();
      await selectLeague(state.leagues[0]?.id ?? null);
      ctx.navigate("leagues");
      toast("League deleted", "good");
      await ctx.rerender();
    },
  }));
}
