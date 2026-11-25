-- Run in Supabase SQL Editor. Database is the source of truth.
create extension if not exists pgcrypto;
create table if not exists public.tickets (
 ticket_no text primary key,
 category text not null check (category in ('A','B','C')),
 amount integer not null check (amount in (100,250,500)),
 status text not null default 'available' check (status in ('available','reserved','sold')),
 reserved_by uuid references auth.users(id),
 reserved_until timestamptz,
 customer_name text,
 phone text,
 payment_mode text,
 payment_reference text,
 sold_by uuid references auth.users(id),
 sold_by_email text,
 sold_at timestamptz,
 sheet_synced_at timestamptz,
 sheet_sync_error text,
 created_at timestamptz not null default now(),
 constraint ticket_category_amount check ((category='A' and amount=500) or (category='B' and amount=250) or (category='C' and amount=100))
);
create table if not exists public.profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 full_name text,
 role text not null default 'volunteer' check (role in ('admin','volunteer')),
 active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists public.ticket_audit (
 id bigint generated always as identity primary key,
 ticket_no text not null references public.tickets(ticket_no),
 action text not null,
 actor uuid references auth.users(id),
 details jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);

insert into public.tickets(ticket_no,category,amount)
select 'A'||lpad(n::text,2,'0'),'A',500 from generate_series(0,99) n on conflict do nothing;
insert into public.tickets(ticket_no,category,amount)
select 'B'||lpad(n::text,2,'0'),'B',250 from generate_series(0,99) n on conflict do nothing;
insert into public.tickets(ticket_no,category,amount)
select 'C'||lpad(n::text,2,'0'),'C',100 from generate_series(0,99) n on conflict do nothing;

alter table public.tickets enable row level security;
alter table public.profiles enable row level security;
alter table public.ticket_audit enable row level security;

create or replace function public.is_active_volunteer() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles p where p.user_id=auth.uid() and p.active=true);
$$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles p where p.user_id=auth.uid() and p.active=true and p.role='admin');
$$;

-- Volunteers can see availability, but customer details are not selected by the app's ticket-grid query.
create policy "active volunteers can view ticket grid" on public.tickets for select to authenticated using (public.is_active_volunteer());
create policy "admins manage profiles" on public.profiles for select to authenticated using (public.is_admin() or user_id=auth.uid());
create policy "admins view audit" on public.ticket_audit for select to authenticated using (public.is_admin());

create or replace function public.reserve_ticket(p_ticket_no text) returns jsonb language plpgsql security definer set search_path=public as $$
declare t public.tickets;
begin
 if not public.is_active_volunteer() then raise exception 'Authorised volunteer access required'; end if;
 update public.tickets set status='available',reserved_by=null,reserved_until=null where status='reserved' and reserved_until < now();
 update public.tickets set status='reserved',reserved_by=auth.uid(),reserved_until=now()+interval '15 minutes'
 where ticket_no=p_ticket_no and status='available' returning * into t;
 if not found then raise exception 'Ticket is no longer available. Refresh and choose another ticket.'; end if;
 insert into public.ticket_audit(ticket_no,action,actor,details) values(p_ticket_no,'reserved',auth.uid(),jsonb_build_object('reserved_until',t.reserved_until));
 return jsonb_build_object('ticket_no',t.ticket_no,'reserved_until',t.reserved_until,'message','Ticket reserved for 15 minutes.');
end; $$;

create or replace function public.confirm_ticket_sale(p_ticket_no text,p_customer_name text,p_phone text,p_payment_mode text,p_payment_reference text default null) returns jsonb language plpgsql security definer set search_path=public as $$
declare t public.tickets;
begin
 if not public.is_active_volunteer() then raise exception 'Authorised volunteer access required'; end if;
 update public.tickets set status='sold',customer_name=trim(p_customer_name),phone=trim(p_phone),payment_mode=p_payment_mode,payment_reference=p_payment_reference,sold_by=auth.uid(),sold_by_email=(select email from auth.users where id=auth.uid()),sold_at=now(),reserved_until=null
 where ticket_no=p_ticket_no and status='reserved' and reserved_by=auth.uid() and reserved_until>now() and length(trim(p_customer_name))>0 and length(trim(p_phone))>=8
 returning * into t;
 if not found then raise exception 'Reservation expired or belongs to another volunteer. Reserve the ticket again.'; end if;
 insert into public.ticket_audit(ticket_no,action,actor,details) values(p_ticket_no,'sold',auth.uid(),jsonb_build_object('customer_name',t.customer_name,'payment_mode',t.payment_mode));
 return jsonb_build_object('ticket_no',t.ticket_no,'status','sold','sold_at',t.sold_at);
end; $$;

revoke all on function public.reserve_ticket(text) from public;
revoke all on function public.confirm_ticket_sale(text,text,text,text,text) from public;
grant execute on function public.reserve_ticket(text) to authenticated;
grant execute on function public.confirm_ticket_sale(text,text,text,text,text) to authenticated;

-- Return only public-to-volunteer ticket status fields. Buyer details remain server/admin-only.
create or replace function public.get_ticket_grid(p_category text)
returns table(ticket_no text,category text,status text,reserved_until timestamptz)
language plpgsql security definer set search_path=public as $$
begin
 if not public.is_active_volunteer() then raise exception 'Authorised volunteer access required'; end if;
 if p_category not in ('A','B','C') then raise exception 'Invalid category'; end if;
 update public.tickets set status='available',reserved_by=null,reserved_until=null where status='reserved' and reserved_until < now();
 return query select t.ticket_no,t.category,t.status,t.reserved_until from public.tickets t where t.category=p_category order by t.ticket_no;
end; $$;
revoke all on function public.get_ticket_grid(text) from public;
grant execute on function public.get_ticket_grid(text) to authenticated;
-- Direct ticket-table reads are intentionally not granted. Use get_ticket_grid for the volunteer grid.
revoke select on public.tickets from anon, authenticated;
