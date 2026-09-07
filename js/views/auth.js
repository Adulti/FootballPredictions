import { html, raw, icon } from "../lib/ui.js";
import { isDemo } from "../lib/store.js";

export function renderAuth() {
  return html`
  <div class="auth">
    <div class="auth__card">
      <div class="auth__brand">
        <div class="brand__mark" style="width:34px;height:34px;font-size:17px">🏆</div>
        <div class="brand__name" style="font-size:19px">${window.PREDICTOR_CONFIG?.APP_NAME || "Predictor"}</div>
      </div>
      <p class="auth__tag">Score prediction leagues — fixtures, weekly results and league tables that remember every week.</p>

      <div class="card">
        <div class="card__body stack">
          ${isDemo ? html`
            <div class="banner">
              ${icon("zap", 15)}
              <span><b>Demo mode.</b> No database is configured, so everything is stored in this browser only.</span>
            </div>
            <button class="btn btn--primary btn--block" id="demo-btn">
              ${icon("check", 16)} Continue in demo mode
            </button>
            <div class="divider">accounts need a database</div>
            <p class="muted" style="font-size:12.5px">
              To run this for real, create a free Supabase project, run
              <code>supabase/schema.sql</code>, and paste your keys into <code>config.js</code>.
              Full steps are in the README.
            </p>
          ` : html`
            <div class="tabs" role="tablist" style="width:fit-content">
              <button data-mode="signin" role="tab" aria-selected="true">Sign in</button>
              <button data-mode="signup" role="tab" aria-selected="false">Sign up</button>
            </div>

            <form id="auth-form" class="stack stack--sm">
              <div class="field" id="name-field" hidden>
                <label for="auth-name">Display name</label>
                <input class="input" id="auth-name" autocomplete="name" placeholder="Alex Morgan" />
              </div>
              <div class="field">
                <label for="auth-email">Email</label>
                <input class="input" id="auth-email" type="email" required autocomplete="email" placeholder="you@example.com" />
              </div>
              <div class="field">
                <label for="auth-pw">Password</label>
                <input class="input" id="auth-pw" type="password" required minlength="6" autocomplete="current-password" placeholder="••••••••" />
              </div>
              <p class="pill pill--bad" id="auth-err" hidden style="white-space:normal;line-height:1.4"></p>
              <button class="btn btn--primary btn--block" id="auth-submit" type="submit">Sign in</button>
            </form>
          `}
        </div>
      </div>

      <p class="muted" style="text-align:center;margin-top:16px;font-size:12px">
        7 pts exact score · 4 pts goal difference · 2 pts outcome · −1 wrong · one double-points banker each week
      </p>
    </div>
  </div>`;
}
