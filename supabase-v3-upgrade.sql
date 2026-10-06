-- Run ONCE in Supabase > SQL Editor, after supabase.sql.
alter table profiles add column if not exists accepted_terms_at timestamptz;

create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, accepted_terms_at) values (new.id, nullif(new.raw_user_meta_data->>'accepted_terms_at','')::timestamptz);
  return new;
end $$;

create table if not exists subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  plan text not null check (plan in ('hh_week','hh_month','tr_month','tr_year')),
  status text not null default 'pending' check (status in ('pending','active','expired','rejected')),
  expires_at timestamptz, created_at timestamptz default now());
alter table subscriptions enable row level security;
create policy "own subs read" on subscriptions for select to authenticated using (user_id = auth.uid());
create policy "own subs request" on subscriptions for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending' and expires_at is null);

create table if not exists reports (
  id bigserial primary key, user_id uuid references auth.users on delete set null,
  item_id uuid references items on delete cascade, note text not null check (length(note) <= 300),
  status text default 'open', created_at timestamptz default now());
alter table reports enable row level security;
create policy "report add" on reports for insert to authenticated with check (user_id = auth.uid());

alter table receipts drop constraint if exists receipts_user_id_fkey;
alter table receipts add constraint receipts_user_id_fkey foreign key (user_id) references auth.users on delete cascade;
alter table prices drop constraint if exists prices_scout_id_fkey;
alter table prices add constraint prices_scout_id_fkey foreign key (scout_id) references auth.users on delete set null;
alter table prices drop constraint if exists price_sane;
alter table prices add constraint price_sane check (price < 1000000);

update storage.buckets set file_size_limit = 5242880, allowed_mime_types = array['image/jpeg','image/png','image/webp'] where id = 'receipts';

create or replace function delete_my_account() returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  delete from storage.objects where bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text;
  delete from auth.users where id = auth.uid();
end $$;
revoke all on function delete_my_account() from public, anon;
grant execute on function delete_my_account() to authenticated;

-- After you receive a MoMo payment, activate the plan (the user sees the 6-character reference in the app):
-- update subscriptions set status = 'active', expires_at = now() + interval '30 days' where id::text ilike 'ab12cd%';
-- Use '7 days' for hh_week and '365 days' for tr_year.
