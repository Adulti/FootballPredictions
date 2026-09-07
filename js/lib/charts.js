/* ==========================================================================
   Charts — hand-rolled inline SVG (no libraries).

   Rules honoured: one y-axis only, categorical hues assigned in fixed order
   and never cycled (series past slot 8 render as recessive neutral context
   lines), thin marks, ≥8px markers, recessive grid, legend whenever there is
   more than one series, direct labels when ≤4 series, hover crosshair +
   tooltip, and a table view of the same numbers always present on the page.
   ========================================================================== */

import { esc, SERIES, debounce } from "./ui.js";

const PAD = { t: 16, r: 74, b: 30, l: 40 };

function niceScale(min, max, ticks = 5) {
  if (min === max) { min -= 1; max += 1; }
  const span = max - min;
  const raw = span / ticks;
  const mag = 10 ** Math.floor(Math.log10(raw));
  const norm = raw / mag;
  const step = (norm >= 5 ? 10 : norm >= 2 ? 5 : norm >= 1 ? 2 : 1) * mag;
  const lo = Math.floor(min / step) * step;
  const hi = Math.ceil(max / step) * step;
  const out = [];
  for (let v = lo; v <= hi + step / 2; v += step) out.push(Math.round(v * 1e6) / 1e6);
  return { lo, hi, ticks: out };
}

/**
 * @param {HTMLElement} host
 * @param {{x:number[], series:Array<{id,name,values:number[]}>, context?:Array,
 *          xLabel?:string, yLabel?:string, height?:number, xPrefix?:string}} cfg
 */
export function renderLineChart(host, cfg) {
  if (!host) return;
  const draw = () => {
    if (!host.isConnected) return;
    const { x = [], series = [], context = [], height = 260, xPrefix = "GW" } = cfg;
    const w = Math.max(320, host.clientWidth || 640);
    const h = height;
    if (!x.length || !series.length) { host.innerHTML = ""; return; }

    const all = [...series, ...context].flatMap((s) => s.values.filter((v) => v !== null && v !== undefined));
    const sc = cfg.invertY
      ? { lo: 1, hi: Math.max(2, ...all), ticks: Array.from({ length: Math.max(2, ...all) }, (_, i) => i + 1) }
      : niceScale(Math.min(0, ...all), Math.max(1, ...all));
    const px = (i) => PAD.l + (x.length === 1 ? 0 : (i * (w - PAD.l - PAD.r)) / (x.length - 1));
    const py = (v) => cfg.invertY
      ? PAD.t + (h - PAD.t - PAD.b) * ((v - sc.lo) / (sc.hi - sc.lo))
      : PAD.t + (h - PAD.t - PAD.b) * (1 - (v - sc.lo) / (sc.hi - sc.lo));

    const path = (vals) =>
      vals.map((v, i) => `${i ? "L" : "M"}${px(i).toFixed(1)},${py(v).toFixed(1)}`).join(" ");

    const gridlines = sc.ticks.map((t) => `
      <line class="${t === 0 ? "zero-line" : "grid-line"}" x1="${PAD.l}" x2="${w - PAD.r}" y1="${py(t)}" y2="${py(t)}"/>
      <text class="axis-label" x="${PAD.l - 8}" y="${py(t) + 3.5}" text-anchor="end">${t}</text>`).join("");

    // x labels: thin out when crowded
    const every = Math.ceil(x.length / Math.max(3, Math.floor((w - PAD.l - PAD.r) / 46)));
    const xlabels = x.map((lab, i) =>
      i % every === 0 || i === x.length - 1
        ? `<text class="axis-label" x="${px(i)}" y="${h - PAD.b + 16}" text-anchor="middle">${xPrefix}${lab}</text>`
        : "").join("");

    const ctxLines = context.map((s) => `<path class="ctx-line" d="${path(s.values)}"/>`).join("");

    const lines = series.map((s, i) => {
      const color = s.color || SERIES[i % SERIES.length];
      const last = s.values.length - 1;
      const label = series.length <= 4
        ? `<text class="direct-label" x="${px(last) + 9}" y="${py(s.values[last]) + 4}" fill="${color}">${esc(shorten(s.name))}</text>`
        : "";
      return `
        <path class="series-line" d="${path(s.values)}" stroke="${color}"/>
        <circle class="series-dot" cx="${px(last)}" cy="${py(s.values[last])}" r="4.5" fill="${color}"/>
        ${label}`;
    }).join("");

    // Identity is never colour-alone: ≥2 series always carry a named legend.
    const legend = series.length >= 2
      ? legendHtml([
          ...series.map((s, i) => ({ id: s.id, name: s.name, color: s.color || SERIES[i % SERIES.length], static: true })),
          ...(context.length ? [{ id: "__ctx", name: `${context.length} other${context.length === 1 ? "" : "s"}`, color: "var(--series-ctx)", static: true }] : []),
        ])
      : "";

    host.innerHTML = `
      ${legend}
      <div class="chart-holder">
        <svg class="chart" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img"
             aria-label="${esc(cfg.aria || "Points progression by gameweek")}">
          ${gridlines}${xlabels}
          <g class="hoverlayer"></g>
          ${ctxLines}${lines}
          <rect class="hit" x="${PAD.l}" y="${PAD.t}" width="${w - PAD.l - PAD.r}"
                height="${h - PAD.t - PAD.b}" fill="transparent" style="cursor:crosshair"/>
        </svg>
        <div class="tip" hidden></div>
      </div>`;

    /* --- hover layer --- */
    const svg = host.querySelector("svg");
    const layer = host.querySelector(".hoverlayer");
    const tip = host.querySelector(".tip");
    const holder = host.querySelector(".chart-holder");
    const hit = host.querySelector(".hit");

    const move = (ev) => {
      const r = svg.getBoundingClientRect();
      const mx = ((ev.clientX - r.left) / r.width) * w;
      let idx = 0, best = Infinity;
      x.forEach((_, i) => { const d = Math.abs(px(i) - mx); if (d < best) { best = d; idx = i; } });

      layer.innerHTML = `<line class="crosshair" x1="${px(idx)}" x2="${px(idx)}" y1="${PAD.t}" y2="${h - PAD.b}"/>` +
        series.map((s, i) => {
          const v = s.values[idx];
          if (v === null || v === undefined) return "";
          return `<circle class="series-dot" cx="${px(idx)}" cy="${py(v)}" r="4.5" fill="${s.color || SERIES[i % SERIES.length]}"/>`;
        }).join("");

      const rows = series
        .map((s, i) => ({ name: s.name, v: s.values[idx], c: s.color || SERIES[i % SERIES.length] }))
        .filter((r0) => r0.v !== null && r0.v !== undefined)
        .sort((a, b) => (cfg.invertY ? a.v - b.v : b.v - a.v))
        .slice(0, 10);

      tip.innerHTML = `<div class="tip__title">${xPrefix}${esc(x[idx])}</div>` +
        rows.map((r0) => `<div class="tip__row">
            <span style="display:flex;align-items:center;gap:6px">
              <i class="legend__swatch" style="background:${r0.c}"></i>${esc(shorten(r0.name, 18))}
            </span><b>${r0.v}</b></div>`).join("");
      tip.hidden = false;

      const hostRect = holder.getBoundingClientRect();
      const scale = hostRect.width / w;
      let left = px(idx) * scale + 14;
      if (left + tip.offsetWidth > hostRect.width) left = px(idx) * scale - tip.offsetWidth - 14;
      tip.style.left = `${Math.max(0, left)}px`;
      tip.style.top = `${Math.min(hostRect.height - tip.offsetHeight, Math.max(0, ev.clientY - hostRect.top - tip.offsetHeight / 2))}px`;
    };

    hit.addEventListener("mousemove", move);
    hit.addEventListener("touchmove", (e) => { if (e.touches[0]) move(e.touches[0]); }, { passive: true });
    const leave = () => { layer.innerHTML = ""; tip.hidden = true; };
    hit.addEventListener("mouseleave", leave);
    hit.addEventListener("touchend", leave);
  };

  draw();
  if (host._chartResize) window.removeEventListener("resize", host._chartResize);
  host._chartResize = debounce(draw, 150);
  window.addEventListener("resize", host._chartResize);
}

/**
 * Single-series bar chart (no legend needed — the title names it).
 * Negative bars render below the zero line.
 */
export function renderBarChart(host, cfg) {
  if (!host) return;
  const draw = () => {
    if (!host.isConnected) return;
    const { labels = [], values = [], height = 190, xPrefix = "GW", colorFor } = cfg;
    const w = Math.max(300, host.clientWidth || 600);
    const h = height;
    if (!labels.length) { host.innerHTML = ""; return; }
    const pad = { ...PAD, r: 16 };
    const sc = niceScale(Math.min(0, ...values), Math.max(1, ...values), 4);
    const plotW = w - pad.l - pad.r;
    const bw = Math.min(46, (plotW / labels.length) * 0.62);
    const cx = (i) => pad.l + (plotW / labels.length) * (i + 0.5);
    const py = (v) => pad.t + (h - pad.t - pad.b) * (1 - (v - sc.lo) / (sc.hi - sc.lo));

    const grid = sc.ticks.map((t) => `
      <line class="${t === 0 ? "zero-line" : "grid-line"}" x1="${pad.l}" x2="${w - pad.r}" y1="${py(t)}" y2="${py(t)}"/>
      <text class="axis-label" x="${pad.l - 8}" y="${py(t) + 3.5}" text-anchor="end">${t}</text>`).join("");

    const bars = values.map((v, i) => {
      const y0 = py(0), y1 = py(v);
      const top = Math.min(y0, y1), hh = Math.max(2, Math.abs(y1 - y0));
      const color = colorFor ? colorFor(v, i) : (v < 0 ? "var(--bad)" : "var(--series-1)");
      return `<g>
        <rect class="bar" x="${cx(i) - bw / 2}" y="${top}" width="${bw}" height="${hh}" fill="${color}"
              stroke="var(--surface-1)" stroke-width="1"><title>${xPrefix}${esc(labels[i])}: ${v} pts</title></rect>
        <text class="axis-label" x="${cx(i)}" y="${v < 0 ? top + hh + 13 : top - 5}" text-anchor="middle"
              style="font-weight:600;fill:var(--text-secondary)">${v}</text>
        <text class="axis-label" x="${cx(i)}" y="${h - pad.b + 16}" text-anchor="middle">${xPrefix}${esc(labels[i])}</text>
      </g>`;
    }).join("");

    host.innerHTML = `<svg class="chart" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img"
      aria-label="${esc(cfg.aria || "Points by gameweek")}">${grid}${bars}</svg>`;
  };
  draw();
  if (host._chartResize) window.removeEventListener("resize", host._chartResize);
  host._chartResize = debounce(draw, 150);
  window.addEventListener("resize", host._chartResize);
}

function shorten(s, n = 14) {
  s = String(s || "");
  return s.length > n ? s.slice(0, n - 1) + "…" : s;
}

/** Legend markup — identity is never colour-alone (the name is always shown). */
export function legendHtml(items) {
  return `<div class="legend" style="margin-bottom:10px">` + items.map((it) => (it.static
    ? `<span class="legend__item" style="cursor:default">
         <i class="legend__swatch" style="background:${it.color}"></i>${esc(it.name)}
       </span>`
    : `<button class="legend__item" type="button" data-legend="${esc(it.id)}"
               aria-pressed="${it.on === false ? "false" : "true"}">
         <i class="legend__swatch" style="background:${it.color}"></i>${esc(it.name)}
       </button>`)).join("") + `</div>`;
}
