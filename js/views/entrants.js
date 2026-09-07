import {
  html, raw, icon, qs, qsa, on, toast, openModal, closeModal, confirmModal,
  downloadCsv, parseCsv, emptyState, initials,
} from "../lib/ui.js";
import { state, api } from "../lib/store.js";
import { derived } from "../lib/derive.js";

export const title = "Entrants";

export async function render(host, ctx) {
  const { table } = derived();
  const byId = new Map(table.map((r) => [r.entrantId, r]));

  host.innerHTML = html`
  <div class="stack">
    <div class="row">
      <button class="btn btn--primary" id="add">${icon("plus", 16)} Add entrant</button>
      <button class="btn" id="bulk">${icon("upload", 15)} Bulk add / import</button>
      <div class="spacer"></div>
      <span class="pill">${state.entrants.length} entrant${state.entrants.length === 1 ? "" : "s"}</span>
      <button class="btn btn--sm" id="csv">${icon("download", 15)} Export</button>
    </div>

    ${state.entrants.length ? html`
    <div class="card">
      <div class="card__head">
        <h3>Everyone in ${state.league.name}</h3>
        <input class="input" id="filter" placeholder="Filter by name or team…" style="max-width:240px" />
      </div>
      <div class="card__body card__body--flush table-wrap">
        <table class="tbl" id="etbl">
          <thead><tr>
            <th>Full name</th><th>Team name</th>
            <th class="num">Points</th><th class="num">Predictions</th>
            <th>Linked account</th><th></th>
          </tr></thead>
          <tbody>
            ${raw(state.entrants.map((e) => {
              const r = byId.get(String(e.id));
              const preds = state.predictions.filter((p) => p.entrant_id === e.id).length;
              const member = state.members.find((m) => m.user_id && m.user_id === e.user_id);
              return html`<tr data-name="${(e.full_name + " " + (e.team_name || "")).toLowerCase()}">
                <td><div class="row" style="gap:9px;flex-wrap:nowrap">
                  <div class="avatar">${initials(e.full_name)}</div>
                  <b>${e.full_name}</b>
                </div></td>
                <td>${e.team_name || html`<span class="muted">—</span>`}</td>
                <td class="num mono">${r ? r.points : 0}</td>
                <td class="num mono">${preds}</td>
                <td>${member
                  ? html`<span class="pill pill--accent">${member.display_name}</span>`
                  : html`<span class="muted" style="font-size:12.5px">—</span>`}</td>
                <td class="num">
                  <button class="btn btn--sm btn--ghost" data-edit="${e.id}" title="Edit">${icon("edit", 14)}</button>
                  <button class="btn btn--sm btn--ghost" data-del="${e.id}" title="Remove">${icon("trash", 14)}</button>
                </td>
              </tr>`;
            }).join(""))}
          </tbody>
        </table>
      </div>
    </div>` : raw(emptyState({
      mark: "👥", title: "No entrants yet",
      body: "Add each person's full name and the team name they're playing under. You can paste a whole list at once.",
      action: `<div class="row" style="justify-content:center"><button class="btn btn--primary" id="add2">Add the first entrant</button></div>`,
    }))}

    <div class="banner banner--info">
      ${icon("zap", 15)}
      <span>Removing an entrant also removes their predictions, and past league tables recalculate without them.</span>
    </div>
  </div>`;

  const reload = () => ctx.rerender({ reload: true });

  qs("#filter", host)?.addEventListener("input", (e) => {
    const q = e.target.value.trim().toLowerCase();
    qsa("#etbl tbody tr", host).forEach((tr) => {
      tr.hidden = q && !tr.dataset.name.includes(q);
    });
  });

  const openForm = (entrant) => openModal({
    title: entrant ? "Edit entrant" : "Add entrant",
    body: html`
      <div class="field">
        <label for="f-name">Full name</label>
        <input class="input" id="f-name" value="${entrant?.full_name || ""}" placeholder="Alex Morgan" required />
      </div>
      <div class="field">
        <label for="f-team">Team name</label>
        <input class="input" id="f-team" value="${entrant?.team_name || ""}" placeholder="Morgan's Marauders" />
        <span class="hint">Shown under their name throughout the app.</span>
      </div>
      ${state.members.length > 1 ? html`
      <div class="field">
        <label for="f-user">Link to an account (optional)</label>
        <select class="select" id="f-user">
          <option value="">Not linked</option>
          ${raw(state.members.map((m) => `<option value="${m.user_id}" ${entrant?.user_id === m.user_id ? "selected" : ""}>${m.display_name}</option>`).join(""))}
        </select>
        <span class="hint">Linked entrants get their row highlighted when that person signs in.</span>
      </div>` : ""}`,
    footer: html`<button class="btn" data-close>Cancel</button>
                 <button class="btn btn--primary" id="save">${entrant ? "Save changes" : "Add entrant"}</button>`,
    onMount(root) {
      qs("#save", root).addEventListener("click", async () => {
        const full_name = qs("#f-name", root).value.trim();
        const team_name = qs("#f-team", root).value.trim();
        const user_id = qs("#f-user", root)?.value || null;
        if (!full_name) { toast("A full name is required", "bad"); return; }
        qs("#save", root).disabled = true;
        try {
          if (entrant) await api.updateEntrant(entrant.id, { full_name, team_name, user_id: user_id || null });
          else await api.addEntrants([{ full_name, team_name, user_id: user_id || null }]);
          closeModal();
          toast(entrant ? "Entrant updated" : `${full_name} added`, "good");
          await reload();
        } catch (ex) { qs("#save", root).disabled = false; toast(ex.message, "bad"); }
      });
    },
  });

  qs("#add", host)?.addEventListener("click", () => openForm(null));
  qs("#add2", host)?.addEventListener("click", () => openForm(null));

  on(host, "click", "[data-edit]", (e, el) => {
    openForm(state.entrants.find((x) => String(x.id) === el.dataset.edit));
  });

  on(host, "click", "[data-del]", (e, el) => {
    const ent = state.entrants.find((x) => String(x.id) === el.dataset.del);
    confirmModal({
      title: "Remove entrant",
      message: `Remove ${ent.full_name} and all of their predictions? This can't be undone.`,
      confirmLabel: "Remove entrant",
      async onConfirm() {
        await api.deleteEntrants([ent.id]);
        toast(`${ent.full_name} removed`, "good");
        await reload();
      },
    });
  });

  qs("#bulk", host)?.addEventListener("click", () => openModal({
    title: "Bulk add entrants",
    wide: true,
    body: html`
      <div class="field">
        <label for="b-text">One per line — <code>Full name, Team name</code></label>
        <textarea class="input" id="b-text" rows="10" style="font-family:var(--mono);font-size:12.5px"
          placeholder="Alex Morgan, Morgan's Marauders&#10;Sam Patel, Patel Palace&#10;Jo Byrne, Byrne Baggies"></textarea>
        <span class="hint">Tab-separated and semicolon-separated lines work too. A missing team name is fine.</span>
      </div>
      <div class="divider">or</div>
      <div class="field">
        <label for="b-file">Import a CSV file</label>
        <input class="input" id="b-file" type="file" accept=".csv,text/csv" />
        <span class="hint">Expects columns <code>full_name</code> and <code>team_name</code> (a header row is detected automatically).</span>
      </div>
      <div id="b-preview"></div>`,
    footer: html`<button class="btn" data-close>Cancel</button>
                 <button class="btn btn--primary" id="b-save" disabled>Add entrants</button>`,
    onMount(root) {
      let rows = [];
      const preview = qs("#b-preview", root);
      const saveBtn = qs("#b-save", root);

      const setRows = (r) => {
        rows = r;
        saveBtn.disabled = !r.length;
        saveBtn.textContent = r.length ? `Add ${r.length} entrant${r.length === 1 ? "" : "s"}` : "Add entrants";
        preview.innerHTML = r.length
          ? html`<div class="table-wrap" style="max-height:220px;overflow:auto">
              <table class="tbl"><thead><tr><th>Full name</th><th>Team name</th></tr></thead>
              <tbody>${raw(r.map((x) => `<tr><td>${x.full_name}</td><td>${x.team_name || "—"}</td></tr>`).join(""))}</tbody></table></div>`
          : "";
      };

      const parseText = (text) => {
        const out = [];
        for (const line of text.split(/\r?\n/)) {
          const t = line.trim();
          if (!t) continue;
          const parts = t.split(/\t|;|,/).map((s) => s.trim());
          if (/^(full[_ ]?name|name)$/i.test(parts[0])) continue; // header
          if (parts[0]) out.push({ full_name: parts[0], team_name: parts[1] || "" });
        }
        return out;
      };

      qs("#b-text", root).addEventListener("input", (e) => setRows(parseText(e.target.value)));
      qs("#b-file", root).addEventListener("change", async (e) => {
        const file = e.target.files[0];
        if (!file) return;
        const grid = parseCsv(await file.text());
        let start = 0;
        if (grid[0] && /name/i.test(grid[0][0])) start = 1;
        setRows(grid.slice(start).filter((r) => r[0]?.trim()).map((r) => ({ full_name: r[0].trim(), team_name: (r[1] || "").trim() })));
      });

      saveBtn.addEventListener("click", async () => {
        saveBtn.disabled = true;
        try {
          await api.addEntrants(rows);
          closeModal();
          toast(`${rows.length} entrants added`, "good");
          await reload();
        } catch (ex) { saveBtn.disabled = false; toast(ex.message, "bad"); }
      });
    },
  }));

  qs("#csv", host)?.addEventListener("click", () => {
    downloadCsv(`${state.league.name} — entrants.csv`,
      [["full_name", "team_name", "points"], ...state.entrants.map((e) => [e.full_name, e.team_name, byId.get(String(e.id))?.points ?? 0])]);
  });
}
