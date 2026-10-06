-- Run this whole file in Supabase > SQL Editor.
create table stores (id uuid primary key default gen_random_uuid(), name text unique not null, kind text default 'retail');
create table items  (id uuid primary key default gen_random_uuid(), name text unique not null, cat text default 'Staples');
create table prices (id bigserial primary key, item_id uuid references items on delete cascade, store_id uuid references stores on delete cascade,
  price numeric not null check (price > 0), scout_id uuid references auth.users, created_at timestamptz default now());
create table packs  (id bigserial primary key, item_id uuid references items on delete cascade, pack text, units int not null, price numeric not null, where_at text);
create table profiles (id uuid primary key references auth.users on delete cascade, role text not null default 'user' check (role in ('user','scout','admin')));
create table receipts (id bigserial primary key, user_id uuid references auth.users, store_id uuid references stores, path text not null,
  status text default 'pending', created_at timestamptz default now());

create view latest_prices as
  select distinct on (item_id, store_id) item_id, store_id, price, created_at from prices order by item_id, store_id, created_at desc;

create function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin insert into profiles (id) values (new.id); return new; end $$;
create trigger on_signup after insert on auth.users for each row execute function handle_new_user();

alter table stores enable row level security; alter table items enable row level security; alter table prices enable row level security;
alter table packs enable row level security; alter table profiles enable row level security; alter table receipts enable row level security;

create policy "read stores" on stores for select using (true);
create policy "read items"  on items  for select using (true);
create policy "read prices" on prices for select using (true);
create policy "read packs"  on packs  for select using (true);
create policy "own profile" on profiles for select using (auth.uid() = id);
create policy "scouts add prices" on prices for insert to authenticated
  with check (scout_id = auth.uid() and exists (select 1 from profiles where id = auth.uid() and role in ('scout','admin')));
create policy "own receipts add"  on receipts for insert to authenticated with check (user_id = auth.uid());
create policy "own receipts read" on receipts for select to authenticated using (user_id = auth.uid());

insert into storage.buckets (id, name, public) values ('receipts', 'receipts', false);
create policy "upload own receipt" on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);

-- Starter data
insert into stores (name, kind) values ('Shoprite','retail'),('Pick n Pay','retail'),('Choppies','retail'),('Soweto Market','market');
insert into items (name, cat) values ('Mealie meal 25kg','Staples'),('Cooking oil 2L','Staples'),('Sugar 2kg','Staples'),('Rice 2kg','Staples'),
  ('Salt 1kg','Staples'),('Eggs tray (30)','Fresh'),('Bread 700g','Fresh'),('Fresh milk 1L','Fresh');
insert into packs (item_id, pack, units, price, where_at)
  select id, 'Bale of 2 x 25kg', 2, 500, 'Soweto Market' from items where name = 'Mealie meal 25kg';

-- To make someone a scout (after they sign up):
-- update profiles set role = 'scout' where id = (select id from auth.users where email = 'scout@example.com');
