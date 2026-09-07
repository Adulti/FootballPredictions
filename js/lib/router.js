/* Minimal hash router shared by the shell and views (kept separate to avoid
   circular imports between app.js and the view modules). */

export const KNOWN = new Set([
  "dashboard", "table", "weeks", "history", "stats",
  "fixtures", "predictions", "entrants", "settings", "leagues",
]);

export function parseHash() {
  const h = (location.hash || "").replace(/^#\/?/, "");
  const [route, ...rest] = h.split("/");
  return { route: KNOWN.has(route) ? route : "dashboard", params: rest };
}

export function navigate(route, ...params) {
  location.hash = `#/${[route, ...params].filter((v) => v !== undefined && v !== null && v !== "").join("/")}`;
}
