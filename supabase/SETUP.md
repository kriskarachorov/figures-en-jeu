# Supabase setup

Status: migrations 001 through 007 applied successfully by the project owner. Migration 008 and the grade-written Edge Function are locally tested but pending deployment and OPENAI_API_KEY setup; see WRITTEN_SETUP.md. Zero-XP accounts have distinct alphabetical ranks. Daily quests and XP limits renew at midnight Europe/Sofia, including daylight saving changes. Database security and scoring tested locally in PGlite; anonymous API access to get_game_state denied on the hosted project. Site and redirect URLs configured by the owner. Existing email delivery settings are unchanged; real email signup and recovery were not retested in this update.

1. Create a Supabase project named `figures-en-jeu`. Choose a Free organization and a European region. Set the database password yourself; do not commit or share it.
2. In SQL Editor, run `migrations/001_progress.sql`, then `migrations/002_gameplay.sql` then `migrations/003_xp_leaderboard.sql` then `migrations/004_rank_messages.sql` then `migrations/005_thursday_learning.sql` then `migrations/006_daily_reset_and_content.sql` and `migrations/007_zero_xp_ranks.sql`, once each. The second migration preserves existing progress and adds rounds, quests and the weekly challenge.
3. In Authentication → URL Configuration, set the Site URL to `https://kriskarachorov.github.io/figures-en-jeu/` and add that same exact URL to Redirect URLs.
4. Obtain the Project URL and publishable key from the project's Connect dialog / API settings. Only those public values belong in the website. Never put a secret or service-role key in this public repository.
5. Connect the frontend to Supabase Auth and the `record_figure_answer` and `get_figure_progress` functions. Test with two distinct accounts before publishing: each should read only its own attempts; direct inserts and updates must be denied; a repeated attempt UUID must not award points twice.

Email sign-up may require custom SMTP before it can send confirmation or reset emails to friends outside the project's team. Check Supabase Auth's email delivery setup before launch. Do not disable confirmation merely to work around delivery restrictions.

Rules prepared: 10 points per correct answer, 5 with a hint, 0 for incorrect answers. Test mode cannot submit a hint. Personal progress is not a competitive anti-cheating system: the game and its answer bank are public.

References:
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/getting-started/api-keys
