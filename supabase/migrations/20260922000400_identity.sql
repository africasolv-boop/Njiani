-- Profiles and drivers.

-- ---------------------------------------------------------------------------
-- profiles
--
-- One row per authenticated user, keyed to Supabase's auth.users. Created by
-- the trigger below the moment a phone number is verified, so no screen ever
-- has to handle "signed in but has no profile".
-- ---------------------------------------------------------------------------
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  -- E.164 without the plus, e.g. 255712345678. Normalised by the app: a
  -- leading zero is stripped, because 0712... and 712... are the same number.
  phone        text not null unique
                 check (phone ~ '^255[0-9]{9}$'),
  display_name text,
  -- Mirrors the device's chosen language so SMS and push land in the right
  -- one. The device preference is what the first screen reads (C2).
  lang         text not null default 'sw' check (lang in ('sw', 'en')),
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- drivers
--
-- The verification gate. `status` is the only thing standing between an
-- unchecked licence and a passenger getting into a stranger's vehicle, so a
-- driver can never write it -- see the RLS migration.
-- ---------------------------------------------------------------------------
create table public.drivers (
  profile_id       uuid primary key
                     references public.profiles(id) on delete cascade,
  vehicle_type     public.vehicle_type not null,
  -- Upper-cased on input: drivers type a plate in every casing there is.
  plate            text not null check (plate = upper(plate) and length(plate) between 4 and 16),
  colour           text not null,
  -- Path in the private storage bucket. Never a public URL.
  licence_path     text,
  status           public.driver_status not null default 'pending',
  -- Written by a person. Required for a rejection: the design is explicit
  -- that an empty rejection must never ship, because the driver is left with
  -- nothing to fix.
  rejection_reason text,
  rating           numeric(2, 1) check (rating between 1.0 and 5.0),
  trips_count      integer not null default 0 check (trips_count >= 0),
  reviewed_at      timestamptz,
  reviewed_by      uuid references public.profiles(id),
  created_at       timestamptz not null default now(),

  constraint rejection_states_a_reason
    check (status <> 'rejected' or rejection_reason is not null),
  -- A driver cannot go live without a licence on file.
  constraint approval_needs_a_licence
    check (status <> 'approved' or licence_path is not null)
);

create index drivers_status_idx on public.drivers (status);
-- The admin verification queue, oldest first.
create index drivers_pending_idx
  on public.drivers (created_at) where status = 'pending';

comment on column public.drivers.status is
  'Admin-only. A driver has no policy allowing them to write this column.';

-- ---------------------------------------------------------------------------
-- A profile appears the moment a phone is verified.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, phone)
  values (
    new.id,
    -- Supabase stores the verified number with a leading '+'.
    regexp_replace(coalesce(new.phone, ''), '^\+', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
