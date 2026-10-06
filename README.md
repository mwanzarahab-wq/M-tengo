# Mitengo (PWA)
## Deploy
Put this folder on Vercel (vercel CLI inside the folder, or import the Git repo). No build step.
## Backend (needed for accounts, plans, receipts, scouts)
1. Supabase SQL Editor: run supabase.sql, then supabase-v3-upgrade.sql.
2. Supabase > Authentication: turn on "Confirm email", set minimum password length to 8, and review the rate limits.
3. Put URL + anon key (and your MOMO_NUMBER) in config.js, redeploy.
## Before launch
- Fill every [BRACKET] in privacy.html and terms.html, then have a Zambian lawyer review both.
- Make a scout: sign up in the app, then run the update at the bottom of supabase.sql.
- Activate a paid plan after you see the MoMo payment: use the update at the bottom of supabase-v3-upgrade.sql.
- REQUIRE_SUBSCRIPTION in config.js: false = everything free (pilot). true = basket, watchlist, wholesale, margin need a plan.
  This is enforced in the app only, so a technical user could bypass it. Move it server-side before you rely on it for revenue.
