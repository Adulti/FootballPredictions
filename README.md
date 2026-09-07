# 🏆 Predictor

A score-prediction league app that runs entirely as static files — so it hosts on
**GitHub Pages for free** — while keeping real, shared state in **Supabase** (hosted
Postgres + auth).

No build step. No bundler. No `npm install`. Just HTML, CSS and ES modules.

---

## Scoring

| Outcome | Points |
| --- | --- |
| Exact score | **7** |
| Goal difference correct | **4** |
| Right outcome only | **2** |
| Wrong | **−1** |
| No prediction submitted | **−2** |
| **Banker** — one fixture per gameweek, per entrant | **×2** on that fixture |

The hierarchy is strict: exact ⊃ goal difference ⊃ outcome, so a 2–1 predicted as
3–2 scores 4 (right margin), not 4 + 2. Every value is editable per league in
**Settings → Scoring rules**, and changing one instantly re-scores every gameweek
and every historic table.

Ties break on: points → exact scores → goal-difference hits → name.

---

## What's in it

**League management**
- Unlimited leagues running side by side, switched from the sidebar picker
- Per-league scoring rules, season label and six-character join code
- Members with admin / viewer roles; entrants can be linked to accounts so a
  person's own row is highlighted when they sign in

**Entrants** — full name + team name, added one at a time, pasted in bulk, or
imported from CSV.

**Fixtures** — grouped by gameweek. Paste a whole week in one go (`Arsenal v Chelsea`,
`Liverpool 2-1 Man City`, `Everton, Spurs` all parse), or import a CSV with
`gameweek, home_team, away_team, kickoff, home_score, away_score`. Scores save the
moment you type them.

**Predictions** — the admin enters everyone's predictions on a grid of entrants ×
fixtures, with a ⚡ banker toggle per row. <kbd>Enter</kbd> jumps down the column so
you can do one fixture for the whole league at a time. There's also a focused
single-entrant form for phones.

**Results & tables**
- Live league table with movement arrows, exact/GD/outcome/miss breakdown, average
  per week, banker profit and a six-week form strip
- **As-of selector** — see the table exactly as it stood after any gameweek
- **Weekly results** — every fixture, every prediction and every points chip for a
  chosen gameweek, with weekly winners
- **Table history** — snapshot per gameweek with a scrubber, a "who led each week"
  log and a position-race chart

**Stats & records** — best/worst week, most exact scores, most weekly wins, best
banker haul, per-entrant profiles with a points-by-gameweek chart, head-to-head
comparison, and the league's most-predicted scorelines with hit rates.

**Everything else** — light/dark/system theme, keyboard-friendly grids, CSV export
on every table, full JSON backup, printable tables, and it works on a phone.

---

## Run it locally

Any static file server will do (ES modules need `http://`, not `file://`):

```bash
npx serve .
# or
python -m http.server 8000
```

Open the address it prints. With no database configured you land in **demo mode**,
pre-seeded with two sample leagues so you can click through everything immediately.

---

## Deploy to GitHub Pages

1. Push this folder to a GitHub repo.
2. **Settings → Pages → Build and deployment → Source: Deploy from a branch**,
   branch `main`, folder `/ (root)`.
3. Done — it's live at `https://<user>.github.io/<repo>/`.

The `.nojekyll` file is there so GitHub serves the `js/` and `css/` folders as-is.

---

## Add the database (real accounts, shared data)

Demo mode keeps everything in one browser's `localStorage`. For a league other
people can actually see, add Supabase — the free tier is far more than enough.

1. Create a project at [supabase.com](https://supabase.com).
2. **SQL Editor → New query**, paste all of [`supabase/schema.sql`](supabase/schema.sql)
   and run it. That creates the tables, indexes, row-level-security policies and the
   `join_league_by_code` function.
3. **Project Settings → API**, copy the **Project URL** and the **anon public** key.
4. Put them in [`config.js`](config.js):

   ```js
   window.PREDICTOR_CONFIG = {
     SUPABASE_URL: "https://xxxxxxxx.supabase.co",
     SUPABASE_ANON_KEY: "eyJhbGciOi...",
     APP_NAME: "Predictor",
   };
   ```

5. Commit and push. The app switches to email/password accounts automatically.

**Optional:** in **Authentication → Providers → Email**, turn off "Confirm email"
while you're testing so sign-ups work instantly. Under **Authentication → URL
Configuration**, add your Pages URL to the redirect allow-list.

### Is it safe to commit the anon key?

Yes — that's what it's for. It only ever acts as the signed-in user, and every table
has row-level security:

- you only see leagues you own or are a member of;
- only admins can write entrants, fixtures and predictions;
- only the owner can delete a league;
- the `service_role` key is the secret one — **never** put that in a static site.

---

## How it's put together

```
index.html            shell + boot splash
config.js             your Supabase keys (or blank for demo mode)
css/app.css           design tokens, components, responsive + print + dark mode
js/app.js             shell, sidebar, routing, theme, auth wiring
js/lib/router.js      hash router
js/lib/store.js       one data API over two backends (Supabase / localStorage)
js/lib/scoring.js     the scoring engine — points, standings, history, records
js/lib/derive.js      memoised derived data (invalidated on any edit)
js/lib/charts.js      inline-SVG line & bar charts with hover crosshairs
js/lib/ui.js          escaping template tag, modals, toasts, icons, CSV
js/views/*.js         one module per page
supabase/schema.sql   tables, indexes, RLS policies, join-by-code RPC
```

Scoring is computed in the browser from raw fixtures and predictions rather than
stored, which is why changing a rule or fixing a score instantly and correctly
rewrites every historic table.

---

## Notes and gotchas

- **Deleting an entrant** removes their predictions, and historic tables recalculate
  as though they were never there. Same for fixtures.
- **Predictions are admin-entered** by design, matching how these leagues usually run
  (someone collects the sheets). Entrants linked to accounts can view but not edit.
- **Demo data** can be reloaded or wiped from **My leagues → Demo mode tools**.
- Charts cap at eight highlighted series; everyone else renders as grey context
  lines, and the exact numbers are always in the table beside the chart.
