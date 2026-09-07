import {
  html, raw, icon, qs, on, toast, openModal, closeModal, confirmModal,
  emptyState, initials, copyText, fmtDate,
} from "../lib/ui.js";
import { state, api, refreshLeagues, selectLeague, isDemo, backend } from "../lib/store.js";
import { invalidate } from "../lib/derive.js";
import { DEFAULT_RULES } from "../lib/scoring.js";

export const title = "My leagues";

export async function render(host, ctx) {
  host.innerHTML = html`
  <div class="stack">
    <div class="row">
      <button class="btn btn--primary" id="new">${icon("plus", 16)} New league</button>
      <button class="btn" id="join">${icon("users", 15)} Join with a code</button>
      <div class="spacer"></div>
      <span class="pill">${state.leagues.length} league${state.leagues.length === 1 ? "" : "s"}</span>
    </div>

    ${state.leagues.length ? html`
    <div class="grid grid--2">
      ${raw(state.leagues.map((l) => {
        const current = String(l.id) === String(state.leagueId);
        return html`
        <div class="card" style="${current ? "border-color:var(--accent)" : ""}">
          <div class="card__head">
            <div class="avatar">${initials(l.name)}</div>
            <div style="margin-right:auto">
              <h3 style="margin:0">${l.name}</h3>
              <div class="muted" style="font-size:12px">${l.season || "No season set"} · created ${fmtDate(l.created_at)}</div>
            </div>
            ${current ? html`<span class="pill pill--accent">Current</span>` : ""}
          </div>
          <div class="card__body stack stack--sm">
            <div class="row">
              <span class="pill ${l.role === "admin" ? "pill--good" : ""}">${l.role === "admin" ? "Admin" : "Viewer"}</span>
              ${l.join_code ? html`<span class="pill mono" title="Join code">${l.join_code}</span>
                <button class="btn btn--sm btn--ghost" data-copy="${l.join_code}" title="Copy join code">${icon("copy", 14)}</button>` : ""}
            </div>
            <div class="row">
              ${current
                ? html`<a class="btn btn--sm" href="#/dashboard">${icon("home", 14)} Open overview</a>`
                : html`<button class="btn btn--sm btn--primary" data-switch="${l.id}">${icon("swap", 14)} Switch to this league</button>`}
              ${l.role === "admin" ? html`<button class="btn btn--sm btn--ghost" data-rename="${l.id}">${icon("edit", 14)} Rename</button>` : ""}
              <div class="spacer"></div>
              ${l.role === "admin"
                ? html`<button class="btn btn--sm btn--danger" data-del="${l.id}">${icon("trash", 14)}</button>`
                : html`<button class="btn btn--sm btn--ghost" data-leave="${l.id}" title="Leave league">${icon("logout", 14)}</button>`}
            </div>
          </div>
        </div>`;
      }).join(""))}
    </div>` : raw(emptyState({
      mark: "🏆", title: "Create your first league",
      body: "A league holds its own entrants, fixtures, predictions and history. You can run as many as you like and switch between them from the sidebar.",
      action: `<div class="row" style="justify-content:center">
        <button class="btn btn--primary" id="new2">Create a league</button>
        <button class="btn" id="join2">I have a join code</button></div>`,
    }))}

    ${isDemo ? html`
    <div class="card">
      <div class="card__head"><h3>Demo mode tools</h3></div>
      <div class="card__body stack stack--sm">
        <p class="muted" style="font-size:12.5px">
          No database is configured, so all of this lives in <code>localStorage</code> in this browser.
          Wire up Supabase (see the README) for real accounts and shared data.
        </p>
        <div class="row">
          <button class="btn btn--sm" id="reseed">${icon("zap", 14)} Reload sample data</button>
          <button class="btn btn--sm btn--danger" id="wipe">${icon("trash", 14)} Wipe everything</button>
        </div>
      </div>
    </div>` : ""}
  </div>`;

  const afterChange = async (leagueId) => {
    invalidate();
    await refreshLeagues();
    await selectLeague(leagueId ?? state.leagues[0]?.id ?? null);
    await ctx.rerender();
  };

  on(host, "click", "[data-copy]", (e, el) => copyText(el.dataset.copy));

  on(host, "click", "[data-switch]", async (e, el) => {
    invalidate();
    await selectLeague(el.dataset.switch);
    toast(`Switched to ${state.league.name}`, "good");
    ctx.navigate("dashboard");
    await ctx.rerender();
  });

  on(host, "click", "[data-rename]", (e, el) => {
    const l = state.leagues.find((x) => String(x.id) === el.dataset.rename);
    openModal({
      title: "Rename league",
      body: html`
        <div class="field"><label for="r-name">League name</label>
          <input class="input" id="r-name" value="${l.name}" /></div>
        <div class="field"><label for="r-season">Season</label>
          <input class="input" id="r-season" value="${l.season || ""}" placeholder="2025/26" /></div>`,
      footer: html`<button class="btn" data-close>Cancel</button><button class="btn btn--primary" id="r-save">Save</button>`,
      onMount(root) {
        qs("#r-save", root).addEventListener("click", async () => {
          const name = qs("#r-name", root).value.trim();
          if (!name) { toast("A name is required", "bad"); return; }
          const season = qs("#r-season", root).value.trim();
          const prev = state.leagueId;
          await selectLeague(l.id);
          await api.updateLeague({ name, season });
          closeModal(); toast("League updated", "good");
          await afterChange(prev);
        });
      },
    });
  });

  on(host, "click", "[data-del]", (e, el) => {
    const l = state.leagues.find((x) => String(x.id) === el.dataset.del);
    confirmModal({
      title: `Delete ${l.name}`,
      message: "Every entrant, fixture, prediction and table snapshot for this league is deleted permanently.",
      confirmLabel: "Delete league",
      async onConfirm() {
        await api.deleteLeague(l.id);
        toast("League deleted", "good");
        await afterChange(null);
      },
    });
  });

  on(host, "click", "[data-leave]", (e, el) => {
    const l = state.leagues.find((x) => String(x.id) === el.dataset.leave);
    confirmModal({
      title: `Leave ${l.name}`,
      message: "You'll stop seeing this league. The admin can send you the join code again.",
      confirmLabel: "Leave league",
      async onConfirm() {
        const prev = state.leagueId;
        await selectLeague(l.id);
        const mine = state.members.find((m) => m.user_id === state.user.id);
        if (mine) await api.removeMember(mine.id);
        toast("Left the league", "good");
        await afterChange(String(prev) === String(l.id) ? null : prev);
      },
    });
  });

  const createModal = () => openModal({
    title: "New league",
    body: html`
      <div class="field"><label for="n-name">League name</label>
        <input class="input" id="n-name" placeholder="Premier Predictions" /></div>
      <div class="field"><label for="n-season">Season <span class="muted">(optional)</span></label>
        <input class="input" id="n-season" placeholder="2025/26" /></div>
      <div class="field">
        <label>Scoring</label>
        <div class="grid" style="grid-template-columns:repeat(2,1fr);gap:10px">
          <div class="field"><label for="n-exact" class="muted">Exact score</label><input class="input input--num" id="n-exact" type="number" value="${DEFAULT_RULES.exact}" /></div>
          <div class="field"><label for="n-gd" class="muted">Goal difference</label><input class="input input--num" id="n-gd" type="number" value="${DEFAULT_RULES.gd}" /></div>
          <div class="field"><label for="n-out" class="muted">Outcome</label><input class="input input--num" id="n-out" type="number" value="${DEFAULT_RULES.outcome}" /></div>
          <div class="field"><label for="n-wrong" class="muted">Wrong</label><input class="input input--num" id="n-wrong" type="number" value="${DEFAULT_RULES.wrong}" /></div>
        </div>
        <span class="hint">Defaults match the classic 7 / 4 / 2 / −1 with a double-points banker each week. Change them any time in Settings.</span>
      </div>`,
    footer: html`<button class="btn" data-close>Cancel</button><button class="btn btn--primary" id="n-save">Create league</button>`,
    onMount(root) {
      qs("#n-save", root).addEventListener("click", async () => {
        const name = qs("#n-name", root).value.trim();
        if (!name) { toast("Give the league a name", "bad"); return; }
        qs("#n-save", root).disabled = true;
        try {
          const league = await api.createLeague({
            name, season: qs("#n-season", root).value.trim(),
            rules: {
              ...DEFAULT_RULES,
              exact: Number(qs("#n-exact", root).value),
              gd: Number(qs("#n-gd", root).value),
              outcome: Number(qs("#n-out", root).value),
              wrong: Number(qs("#n-wrong", root).value),
            },
          });
          closeModal();
          toast(`${league.name} created`, "good");
          await afterChange(league.id);
          ctx.navigate("entrants");
        } catch (ex) { qs("#n-save", root).disabled = false; toast(ex.message, "bad"); }
      });
    },
  });

  const joinModal = () => openModal({
    title: "Join a league",
    body: html`
      <div class="field"><label for="j-code">Join code</label>
        <input class="input mono" id="j-code" placeholder="ABC123" style="letter-spacing:.15em;text-transform:uppercase" /></div>
      <p class="muted" style="font-size:12.5px">Ask the league admin for the six-character code shown on their overview page. You'll join as a viewer.</p>`,
    footer: html`<button class="btn" data-close>Cancel</button><button class="btn btn--primary" id="j-go">Join</button>`,
    onMount(root) {
      qs("#j-go", root).addEventListener("click", async () => {
        const code = qs("#j-code", root).value.trim();
        if (!code) return;
        qs("#j-go", root).disabled = true;
        try {
          const l = await api.joinLeague(code);
          closeModal(); toast(`Joined ${l.name}`, "good");
          await afterChange(l.id);
        } catch (ex) { qs("#j-go", root).disabled = false; toast(ex.message, "bad"); }
      });
    },
  });

  qs("#new", host)?.addEventListener("click", createModal);
  qs("#new2", host)?.addEventListener("click", createModal);
  qs("#join", host)?.addEventListener("click", joinModal);
  qs("#join2", host)?.addEventListener("click", joinModal);

  qs("#reseed", host)?.addEventListener("click", () => confirmModal({
    title: "Reload sample data",
    message: "This replaces everything in this browser with a fresh set of demo leagues.",
    confirmLabel: "Reload sample data", danger: false,
    async onConfirm() { backend.reseedDemo(); location.reload(); },
  }));
  qs("#wipe", host)?.addEventListener("click", () => confirmModal({
    title: "Wipe demo data",
    message: "Deletes every league stored in this browser. There's no undo.",
    confirmLabel: "Wipe everything",
    async onConfirm() { backend.resetDemo(); location.reload(); },
  }));
}
