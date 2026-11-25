# Kristanjali Lucky Draw Manager (starter implementation)

Private volunteer-only Next.js + Supabase starter for the 300-ticket Christmas Triple Fortune draw.

## Included
- Volunteer email/password login (accounts must be created by an administrator in Supabase; no public sign-up UI).
- A/B/C ticket grid with availability states and realtime refresh.
- 15-minute reservation using a database-side atomic update.
- Payment confirmation and buyer details saved to Supabase.
- SQL seed for A00-A99, B00-B99 and C00-C99.
- Google Sheets append helper and a protected sync API route.

## Important status
This is a starter codebase, not a deployed or fully production-audited service. Before real ticket sales, finish the setup below, test with concurrent volunteer accounts, and have the draw model cleared by the relevant authority.

## Setup
1. Create a Supabase project.
2. Run `supabase/schema.sql` in Supabase SQL Editor.
3. In Supabase Authentication, disable public sign-ups. Create volunteer accounts manually.
4. Insert a profile row for each account in `public.profiles` with `role='volunteer'` or `role='admin'`, and `active=true`.
5. Configure `.env.local` from `.env.example`. Keep `SUPABASE_SERVICE_ROLE_KEY` and Google service-account credentials server-only. Never use a `NEXT_PUBLIC_` prefix for secrets.
6. Create a Google Sheet with `Master Register` and `Sales Log` tabs. Add the headers `Ticket No, Category, Customer Name, Mobile, Amount, Payment Mode, Payment Reference, Volunteer, Sold At, Status` to both tabs. Pre-populate Master Register with all 300 ticket numbers (A00–A99, B00–B99, C00–C99) in column A; the sync updates the matching row and also appends a row to Sales Log.
7. Share the Google Sheet with the service-account email as Editor. Set `GOOGLE_SHEET_ID` and service account credentials.
8. Install dependencies with `npm install`, then run `npm run dev`.
9. Deploy to Vercel and configure the same environment variables.

## Required production hardening before launch
- Implement a durable transactional outbox and scheduled retry worker for Google Sheets sync. The current UI makes a best-effort sync call after sale; a transient Google API failure leaves the sale safely stored in Supabase but requires a retry process.
- The SQL includes a restricted `get_ticket_grid` RPC and revokes direct volunteer SELECT on the tickets table. Complete a security review of all policies and functions before launch.
- Add admin-only volunteer management, sales reporting, export, reservation release, and audit screens.
- Add explicit payment verification workflow and prevent volunteers from marking unverified transfers as paid if that is required by committee policy.
- Add admin approval for refunds/corrections and audit every change.
- Add rate limiting, monitoring, backup and security review.

## Google Sheets sync design
The database is authoritative. Sheets is a reporting copy. The sync endpoint reads a sold ticket from Supabase and appends it to `Sales Log`. For production, use a transactional outbox table and a scheduled retry worker, and upsert the Master Register by ticket number to avoid duplicate rows.

## Username login and administrator-created volunteers

1. Run `supabase/username-login-migration.sql` in Supabase SQL Editor.
2. Add `SUPABASE_SERVICE_ROLE_KEY` to the server environment (Vercel project environment variables and local `.env.local`). Never put this key in a `NEXT_PUBLIC_` variable or commit it.
3. Existing administrator accounts can continue logging in with their existing email and password (the login field accepts either email or username).
4. From the Administrator Dashboard, create volunteer accounts with a username and password. Volunteers use the username and password; no email inbox or email confirmation is involved.
5. Redeploy after setting the environment variable.

Username accounts are mapped internally to synthetic addresses ending in `@volunteer.kristanjali.invalid`. This is a login convenience; access is still protected by Supabase Auth, profile status, and the existing database role checks.
