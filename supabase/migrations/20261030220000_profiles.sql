-- Island Pet: user profiles
-- Paste into the Supabase SQL editor (or run with `supabase db push`). Safe to re-run.

create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text,
  avatar_url  text,
  created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- People can read and update only their own row. No insert/delete policy: rows are created by
-- the trigger below and removed by the cascade when the auth user is deleted.
drop policy if exists "Profiles are readable by their owner" on public.profiles;
create policy "Profiles are readable by their owner"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "Profiles are updatable by their owner" on public.profiles;
create policy "Profiles are updatable by their owner"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Create a profile for every new auth user, pulling the name and picture that Google / Apple
-- put into the user's metadata when available.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Apple only sends the name on the first authorization, and the app saves it to the user's
-- metadata right after the user row exists. Fill an empty profile name from that update.
create or replace function public.handle_user_metadata_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set full_name = coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name')
  where id = new.id
    and full_name is null
    and coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name') is not null;
  return new;
end;
$$;

drop trigger if exists on_auth_user_metadata_updated on auth.users;
create trigger on_auth_user_metadata_updated
  after update of raw_user_meta_data on auth.users
  for each row execute function public.handle_user_metadata_update();
