-- Run this in the Supabase SQL Editor before deploying the username-login update.
-- Username accounts use synthetic, non-deliverable email addresses internally.
alter table public.profiles add column if not exists username text;
create unique index if not exists profiles_username_lower_unique
  on public.profiles (lower(username)) where username is not null;

-- Optional: set a username for an existing admin profile for documentation/admin reference.
-- The existing admin can continue signing in with their existing email until changed separately.
-- update public.profiles set username='adminname' where user_id='YOUR-ADMIN-UUID';
