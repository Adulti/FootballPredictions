/* ---------------------------------------------------------------------------
 * Predictor configuration
 * ---------------------------------------------------------------------------
 * Leave SUPABASE_URL / SUPABASE_ANON_KEY empty to run in DEMO mode, which
 * stores everything in this browser's localStorage (no account needed).
 *
 * To go multi-user (real DB + logins):
 *   1. Create a free project at https://supabase.com
 *   2. Run  supabase/schema.sql  in the SQL editor
 *   3. Paste the Project URL + anon (public) key below and commit.
 *
 * The anon key is designed to be public — row level security in schema.sql is
 * what protects the data.
 * ------------------------------------------------------------------------- */
window.PREDICTOR_CONFIG = {
  SUPABASE_URL: "",
  SUPABASE_ANON_KEY: "",

  // Optional: shown in the sidebar footer.
  APP_NAME: "Predictor",
};
