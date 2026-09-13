/* ==========================================================================
   UI helpers — DOM, templating, toasts, modals, icons, CSV
   ========================================================================== */

export const qs = (sel, root = document) => root.querySelector(sel);
export const qsa = (sel, root = document) => [...root.querySelectorAll(sel)];

export function esc(v) {
  if (v === null || v === undefined) return "";
  return String(v).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

/**
 * A string that is already trusted markup. Extends String so it can be handed
 * straight to `innerHTML` or interpolated into a plain template literal, while
 * still being recognisable by `html` so nested templates aren't double-escaped.
 */
class Raw extends String {
  get __raw() { return true; }
  get value() { return String(this); }
}

export const raw = (value) => new Raw(value === null || value === undefined ? "" : value);
export const isRaw = (v) => v instanceof Raw || (v && v.__raw === true);

/** Tagged template that escapes interpolations. Nested `html`/`raw` pass through. */
export function html(strings, ...vals) {
  const out = strings.reduce((acc, s, i) => {
    const v = vals[i - 1];
    let piece;
    if (v === undefined || v === null || v === false) piece = "";
    else if (isRaw(v)) piece = String(v);
    else if (Array.isArray(v)) piece = v.map((x) => (isRaw(x) ? String(x) : esc(x))).join("");
    else piece = esc(v);
    return acc + piece + s;
  });
  return new Raw(out);
}

/** Event delegation: on(root, 'click', '.sel', handler) */
export function on(root, type, sel, handler) {
  root.addEventListener(type, (ev) => {
    const target = ev.target.closest(sel);
    if (target && root.contains(target)) handler(ev, target);
  });
}

/* ---------- formatting ---------- */
export const fmtSigned = (n) => (n > 0 ? `+${n}` : String(n));
export const fmt1 = (n) => (Math.round(n * 10) / 10).toFixed(1);

export function initials(name) {
  return (name || "?").trim().split(/\s+/).slice(0, 2).map((p) => p[0]).join("").toUpperCase();
}

export function fmtDate(iso, opts) {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(+d)) return "—";
  return d.toLocaleDateString(undefined, opts || { day: "numeric", month: "short", year: "numeric" });
}
export function fmtDateTime(iso) {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(+d)) return "—";
  return d.toLocaleString(undefined, { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
}
/** For <input type="datetime-local"> */
export function toLocalInput(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(+d)) return "";
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** 1 -> "1st", 12 -> "12th", 23 -> "23rd" */
export function ordinal(n) {
  const i = Number(n);
  if (!Number.isFinite(i)) return String(n);
  const rem100 = Math.abs(i) % 100;
  const suffix = rem100 >= 11 && rem100 <= 13 ? "th"
    : ["th", "st", "nd", "rd"][Math.abs(i) % 10] || "th";
  return `${i}${suffix}`;
}

/** Same wording as the badge, without markup — for CSV and print. */
export function movementText(m) {
  if (m === null || m === undefined) return "New";
  if (m > 0) return `Up ${m}`;
  if (m < 0) return `Down ${-m}`;
  return "No move";
}

/**
 * Rank movement since the previous completed gameweek, in words:
 * "Up 2" (green), "Down 2" (red), "No move" (amber), "New" for a first
 * appearance. Pass `prevRank` to name last week's position in the tooltip.
 */
export function movementBadge(m, prevRank = null) {
  const was = prevRank === null || prevRank === undefined ? "" : ` — was ${ordinal(prevRank)}`;
  const places = (n) => `${n} place${n === 1 ? "" : "s"}`;
  if (m === null || m === undefined) {
    return html`<span class="mv mv--new" title="Not in last week's table">New</span>`;
  }
  if (m > 0) return html`<span class="mv mv--up" title="Up ${places(m)}${was}">▲ Up ${m}</span>`;
  if (m < 0) return html`<span class="mv mv--down" title="Down ${places(-m)}${was}">▼ Down ${-m}</span>`;
  return html`<span class="mv mv--same" title="Same position as last week${was}">No move</span>`;
}

export const rankClass = (r) => (r <= 3 ? `rank rank--${r}` : "rank");

/* ---------- icons (lucide-ish, inline so nothing loads) ---------- */
const ICONS = {
  home: '<path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/>',
  table: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 10h18M9 10v10"/>',
  calendar: '<rect x="3" y="4.5" width="18" height="16" rx="2"/><path d="M3 9.5h18M8 3v3M16 3v3"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/>',
  edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
  users: '<circle cx="9" cy="8" r="3.2"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M17 8.2a3 3 0 0 1 0 5.6M18 20a6.4 6.4 0 0 0-2-4.3"/>',
  chart: '<path d="M4 20V4"/><path d="M4 20h16"/><path d="M8 16v-5M13 16V7M18 16v-8"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1V21a2 2 0 1 1-4 0v-.1A1.6 1.6 0 0 0 7.5 19.4l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.6 1.6 0 0 0 4.6 14H4.5a2 2 0 1 1 0-4h.1a1.6 1.6 0 0 0 1.1-2.7l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1A1.6 1.6 0 0 0 11 3.4V3a2 2 0 1 1 4 0v.4a1.6 1.6 0 0 0 2.7 1.1l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1A1.6 1.6 0 0 0 21 10h.4a2 2 0 1 1 0 4H21a1.6 1.6 0 0 0-1.6 1Z"/>',
  history: '<path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5"/><path d="M12 8v4.5l3 1.8"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  trash: '<path d="M4 7h16"/><path d="M9 7V4h6v3"/><path d="M6 7l1 13h10l1-13"/>',
  check: '<path d="M4 12.5 9 18 20 6"/>',
  x: '<path d="M6 6l12 12M18 6 6 18"/>',
  chevronDown: '<path d="M6 9l6 6 6-6"/>',
  chevronLeft: '<path d="M15 6l-6 6 6 6"/>',
  chevronRight: '<path d="M9 6l6 6-6 6"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4"/>',
  moon: '<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5Z"/>',
  menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
  logout: '<path d="M9 20H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h4"/><path d="M16 17l5-5-5-5"/><path d="M21 12H9"/>',
  trophy: '<path d="M8 4h8v5a4 4 0 0 1-8 0Z"/><path d="M8 6H5a3 3 0 0 0 3 3"/><path d="M16 6h3a3 3 0 0 1-3 3"/><path d="M12 13v4M9 21h6M10 21l.5-4M14 21l-.5-4"/>',
  star: '<path d="m12 3.5 2.7 5.6 6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1L3.2 10l6.1-.9Z"/>',
  download: '<path d="M12 3v12"/><path d="m7 11 5 5 5-5"/><path d="M4 21h16"/>',
  upload: '<path d="M12 21V9"/><path d="m7 13 5-5 5 5"/><path d="M4 4h16"/>',
  copy: '<rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h8"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
  swap: '<path d="M7 4 3 8l4 4"/><path d="M3 8h13a4 4 0 0 1 0 8H9"/>',
  zap: '<path d="M13 2 4 14h7l-1 8 9-12h-7Z"/>',
  target: '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4.5"/><circle cx="12" cy="12" r=".8" fill="currentColor"/>',
  print: '<path d="M7 8V3h10v5"/><rect x="4" y="8" width="16" height="8" rx="2"/><path d="M7 16h10v5H7z"/>',
};

export function icon(name, size = 17) {
  const p = ICONS[name] || ICONS.star;
  return raw(`<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor"
    stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${p}</svg>`);
}

/* ---------- toasts ---------- */
export function toast(msg, kind = "") {
  const root = qs("#toasts");
  const el = document.createElement("div");
  el.className = "toast" + (kind ? ` toast--${kind}` : "");
  el.innerHTML = html`${kind === "good" ? icon("check", 15) : kind === "bad" ? icon("x", 15) : icon("zap", 15)}<span>${msg}</span>`;
  root.appendChild(el);
  setTimeout(() => { el.style.opacity = "0"; el.style.transition = "opacity .25s"; }, 2800);
  setTimeout(() => el.remove(), 3100);
}

/* ---------- modal ---------- */
let modalCleanup = null;
export function closeModal() {
  const root = qs("#modal-root");
  root.innerHTML = "";
  if (modalCleanup) { modalCleanup(); modalCleanup = null; }
}

/**
 * openModal({ title, body, footer, wide, onMount })
 * `body`/`footer` are HTML strings. onMount(rootEl) wires events.
 */
export function openModal({ title, body, footer = "", wide = false, onMount }) {
  const root = qs("#modal-root");
  root.innerHTML = html`
    <div class="modal-backdrop" data-close>
      <div class="modal ${wide ? "modal--wide" : ""}" role="dialog" aria-modal="true" aria-label="${title}">
        <div class="modal__head">
          <h2>${title}</h2>
          <button class="btn btn--ghost btn--icon" data-close aria-label="Close">${icon("x")}</button>
        </div>
        <div class="modal__body">${raw(body)}</div>
        ${footer ? raw(`<div class="modal__foot">${footer}</div>`) : ""}
      </div>
    </div>`;
  const backdrop = qs(".modal-backdrop", root);
  backdrop.addEventListener("mousedown", (e) => { if (e.target === backdrop) closeModal(); });
  qsa("[data-close]", root).forEach((b) => {
    if (b !== backdrop) b.addEventListener("click", closeModal);
  });
  const onKey = (e) => { if (e.key === "Escape") closeModal(); };
  document.addEventListener("keydown", onKey);
  modalCleanup = () => document.removeEventListener("keydown", onKey);
  const firstInput = qs("input,select,textarea", root);
  if (firstInput) setTimeout(() => firstInput.focus(), 40);
  if (onMount) onMount(root);
  return root;
}

export function confirmModal({ title, message, confirmLabel = "Delete", danger = true, onConfirm }) {
  openModal({
    title,
    body: html`<p class="muted">${message}</p>`,
    footer: html`
      <button class="btn" data-close>Cancel</button>
      <button class="btn ${danger ? "btn--danger" : "btn--primary"}" id="do-confirm">${confirmLabel}</button>`,
    onMount(root) {
      qs("#do-confirm", root).addEventListener("click", async () => {
        const btn = qs("#do-confirm", root);
        btn.disabled = true;
        try { await onConfirm(); closeModal(); }
        catch (e) { btn.disabled = false; toast(e.message || "Something went wrong", "bad"); }
      });
    },
  });
}

/* ---------- CSV ---------- */
export function toCsv(rows) {
  return rows.map((r) => r.map((c) => {
    const s = c === null || c === undefined ? "" : String(c);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  }).join(",")).join("\r\n");
}

export function downloadCsv(filename, rows) {
  const blob = new Blob(["﻿" + toCsv(rows)], { type: "text/csv;charset=utf-8" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

/** Very small CSV parser (handles quotes + CRLF). */
export function parseCsv(text) {
  const rows = []; let row = [], cell = "", inQ = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQ) {
      if (c === '"') { if (text[i + 1] === '"') { cell += '"'; i++; } else inQ = false; }
      else cell += c;
    } else if (c === '"') inQ = true;
    else if (c === ",") { row.push(cell); cell = ""; }
    else if (c === "\n") { row.push(cell); rows.push(row); row = []; cell = ""; }
    else if (c !== "\r") cell += c;
  }
  if (cell !== "" || row.length) { row.push(cell); rows.push(row); }
  return rows.filter((r) => r.some((c) => c.trim() !== ""));
}

export async function copyText(text) {
  try { await navigator.clipboard.writeText(text); toast("Copied to clipboard", "good"); }
  catch { toast("Couldn't copy — select it manually", "bad"); }
}

/* ---------- wide-table scrolling ---------- */
/**
 * Give a horizontally scrolling element a mirrored scrollbar above it, so a
 * wide table can be panned without scrolling to the bottom of the page first.
 * The bar hides itself when there is nothing to scroll.
 *
 * Safe to call repeatedly — a re-render replaces the host's DOM, and the old
 * ResizeObserver is dropped with it.
 *
 * @param {HTMLElement|null} wrap the overflow-x container (e.g. .table-wrap)
 */
export function syncScrollbars(wrap) {
  if (!wrap || wrap.previousElementSibling?.classList.contains("scroll-sync")) return;

  const bar = document.createElement("div");
  bar.className = "scroll-sync";
  bar.setAttribute("aria-hidden", "true");
  bar.hidden = true; // shown by measure(), once we know there is overflow
  const spacer = document.createElement("i");
  bar.append(spacer);
  wrap.before(bar);

  const measure = () => {
    // Views render into #app while it is still hidden during boot, where every
    // width reads as 0. That is "not laid out yet", not "nothing to scroll" —
    // so wait for a real width instead of concluding the bar isn't needed.
    if (!wrap.clientWidth) {
      if (wrap.isConnected) requestAnimationFrame(measure);
      return;
    }
    const w = wrap.scrollWidth;
    spacer.style.width = `${w}px`;
    bar.hidden = w <= wrap.clientWidth + 1;
  };

  // Mirror in both directions. Writing scrollLeft fires a scroll event back on
  // the other element, which is why the write is guarded by a comparison: the
  // echo finds the two already in step and stops there. No "who is driving"
  // flag to get stuck — a dropped or coalesced event just self-corrects on the
  // next one. The 1px tolerance absorbs sub-pixel rounding.
  const link = (from, to) => from.addEventListener("scroll", () => {
    if (Math.abs(to.scrollLeft - from.scrollLeft) > 1) to.scrollLeft = from.scrollLeft;
  }, { passive: true });
  link(bar, wrap);
  link(wrap, bar);

  measure();
  // Web fonts and late layout can change the table's width after first paint.
  requestAnimationFrame(measure);

  if (typeof ResizeObserver === "function") {
    const ro = new ResizeObserver(measure);
    ro.observe(wrap);
    if (wrap.firstElementChild) ro.observe(wrap.firstElementChild);
    // Pin the observer to the element it watches, so it lives exactly as long.
    wrap._scrollSync = ro;
  }

  const onResize = () => {
    if (!wrap.isConnected) { window.removeEventListener("resize", onResize); return; }
    measure();
  };
  window.addEventListener("resize", onResize, { passive: true });

  return measure;
}

/* ---------- misc ---------- */
export function debounce(fn, ms = 300) {
  let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
}

export const SERIES = Array.from({ length: 8 }, (_, i) => `var(--series-${i + 1})`);

export function emptyState({ mark = "📋", title, body, action = "" }) {
  return html`<div class="empty">
    <div class="empty__mark">${mark}</div>
    <h3>${title}</h3>
    <p>${body}</p>
    ${raw(action)}
  </div>`;
}
