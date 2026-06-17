# PropManager — Go-Live Guide

A single static `index.html` backed by Supabase (database, auth, file storage).
Going live = host the static file + lock down Supabase for multiple users.

Do the steps **in order**. Step 1 (security) is mandatory before inviting anyone.

---

## 1. Secure Supabase (MANDATORY for multiple users)

The Supabase anon key is public (it's in the page source). The ONLY thing
stopping user A from reading/deleting user B's data is Row Level Security.

1. Open the [Supabase Dashboard](https://supabase.com/dashboard) → your project.
2. Left menu → **SQL Editor** → **New query**.
3. Paste the entire contents of [`supabase-setup.sql`](./supabase-setup.sql) and click **Run**.
4. Confirm success (no red errors). The script:
   - turns on RLS for `app_data` and adds "own-rows-only" policies,
   - enforces one data row per user,
   - enables realtime sync,
   - makes the `tenant-docs` bucket private with per-user folder access.

**Quick test:** create two accounts, add a property in each, and confirm
neither sees the other's data.

---

## 2. Host on Cloudflare Pages (connected to GitHub)

The repo is already on GitHub (`barakn770-cmyk/propmanager`), so Cloudflare can
auto-deploy on every `git push`.

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com) → **Workers & Pages**
   → **Create** → **Pages** → **Connect to Git**.
2. Authorize GitHub and pick the **propmanager** repo.
3. Build settings:
   - **Framework preset:** `None`
   - **Build command:** *(leave empty)*
   - **Build output directory:** `/`
4. **Save and Deploy.** In ~1 minute you get a URL like
   `https://propmanager-xxx.pages.dev`.

Every future `git push` to `main` redeploys automatically.

---

## 3. Point Supabase Auth at the live URL

Google/email login redirects back to wherever the app runs, so the live URL
must be on Supabase's allow-list.

1. Supabase Dashboard → **Authentication** → **URL Configuration**.
2. **Site URL:** `https://propmanager-xxx.pages.dev`
3. **Redirect URLs:** add `https://propmanager-xxx.pages.dev/**`
   (and your custom domain `/**` later, if you add one).
4. Save.

> Google OAuth itself needs no change — its redirect URI points at
> `https://<your-project>.supabase.co/auth/v1/callback`, which already works.

---

## 4. (Optional) Custom domain

In Cloudflare Pages → your project → **Custom domains** → add your domain.
Then add `https://yourdomain.com/**` to the Supabase Redirect URLs (step 3).

---

## 5. Per-user notes

- **AI assistant:** each user pastes their own Anthropic API key in
  Settings → AI Assistant. It is stored only in that user's browser
  (`localStorage`) and never sent to your server.
- **Email confirmation:** by default Supabase emails a confirmation link on
  sign-up. Configure templates/SMTP under Authentication → Emails, or disable
  confirmation under Authentication → Providers → Email for quicker onboarding.

---

## Go-live checklist

- [ ] Ran `supabase-setup.sql` with no errors
- [ ] Verified two test accounts can't see each other's data
- [ ] Cloudflare Pages deploy is live and loads
- [ ] Site URL + Redirect URLs set in Supabase
- [ ] Logged in with Google AND email/password on the live URL
- [ ] Uploaded a tenant document and re-opened it (storage works)
