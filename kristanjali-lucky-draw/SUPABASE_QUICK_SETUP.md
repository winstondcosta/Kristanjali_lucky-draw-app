# Create the Kristanjali database (Supabase)

A hosted database is needed because multiple volunteers will use the app from different phones. A local SQLite database on one laptop will not safely provide shared, real-time ticket locking.

## 1. Create your free Supabase project

1. Open https://supabase.com and sign in (or create an account).
2. Choose **New project**.
3. Create an organisation if prompted.
4. Project name: `kristanjali-lucky-draw`.
5. Choose a strong database password and save it in your password manager.
6. Choose a region close to Karnataka/India if available (for example, Mumbai if offered).
7. Create the project and wait for provisioning to finish.

The project must be created under your account. ChatGPT cannot create or accept ownership of a project inside your Supabase account.

## 2. Create all 300 ticket records

1. In the Supabase project, open **SQL Editor**.
2. Choose **New query**.
3. Open `supabase/schema.sql` from this starter project.
4. Copy the complete contents into the SQL Editor.
5. Click **Run**.
6. In **Table Editor**, verify that `public.tickets` contains 300 rows: A00–A99, B00–B99 and C00–C99.

Run this verification query in SQL Editor:

```sql
select category, status, count(*)
from public.tickets
group by category, status
order by category, status;
```

A new project should show 100 available tickets in each category.

## 3. Turn off public sign-ups

1. Open **Authentication → Providers → Email** (the exact menu label may vary).
2. Disable public sign-ups / new user sign-ups.
3. Volunteers must not be able to create their own accounts.

## 4. Create volunteer accounts

1. Open **Authentication → Users → Add user**.
2. Create an account for each volunteer using their email address.
3. For each created user, copy the user UUID.
4. Add their profile in SQL Editor, replacing the example values:

```sql
insert into public.profiles (user_id, full_name, role, active)
values ('PASTE-AUTH-USER-UUID-HERE', 'Volunteer Name', 'volunteer', true);
```

For the committee administrator, use `role = 'admin'`:

```sql
insert into public.profiles (user_id, full_name, role, active)
values ('PASTE-ADMIN-USER-UUID-HERE', 'Committee Admin', 'admin', true);
```

Do not share accounts between volunteers. Do not put the database password or service-role key in the browser or in a public repository.

## 5. Copy the app connection details

In **Project Settings → API** (or **Connect**), copy:
- Project URL
- Publishable/anon key
- Service-role/secret key (server only; never expose this to volunteers)

Put the values in `.env.local` on the app host. Use `.env.example` as the template. Never prefix the service-role key with `NEXT_PUBLIC_`.

## 6. Before real ticket sales

This starter is not yet a production-ready deployment. Complete the admin screens, durable Google Sheets sync/retry, payment verification, and security review. Test with at least two volunteer accounts trying to reserve the same ticket at the same time. Only one should succeed. Confirm that volunteers see ticket status but not buyer names or phone numbers.

Do not collect money or issue tickets until the app has passed those tests and the draw has the required legal clearance.
