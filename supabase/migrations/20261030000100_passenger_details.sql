-- A passenger's name, and an optional email. Component C8 follow-on.
--
-- `display_name` has existed since C3 and only driver sign-up ever set it, so
-- a passenger reached a driver's vehicle as nobody. From C10 a driver sees
-- who they are picking up, and "a passenger" is not a thing you can call out
-- at a stage.
--
-- Email is optional and always will be. Njiani signs in by phone (D10) and
-- nothing in the product needs an address; it is here for a receipt a
-- passenger asks for and for reaching someone whose phone has gone. A
-- required one would be a field people put `a@a.com` in.

set search_path = public, extensions;

alter table public.profiles
  add column if not exists email text;

-- Deliberately loose. The job of this check is to catch a typed-in phone
-- number or a stray space, not to adjudicate what an address may contain --
-- that is a famously bad idea, and the only real test of an address is
-- sending to it.
alter table public.profiles
  drop constraint if exists email_looks_like_one;
alter table public.profiles
  add constraint email_looks_like_one
  check (email is null or email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$');

comment on column public.profiles.email is
  'Optional. Njiani signs in by phone; this is for receipts and for reaching '
  'someone whose phone has gone.';

-- Case and whitespace are not identity. Stored as typed is how one person
-- becomes two rows.
create or replace function public.normalise_profile_email()
returns trigger
language plpgsql
as $$
begin
  new.email := nullif(lower(trim(coalesce(new.email, ''))), '');
  new.display_name := nullif(trim(coalesce(new.display_name, '')), '');
  return new;
end;
$$;

drop trigger if exists profiles_normalise on public.profiles;
create trigger profiles_normalise
  before insert or update of email, display_name on public.profiles
  for each row execute function public.normalise_profile_email();

-- ---------------------------------------------------------------------------
-- Column privileges.
--
-- `profiles_update_own` already scopes writes to the owner's row, but RLS
-- cannot protect a single column and `phone` is the account's identity:
-- Supabase Auth owns it, the trigger copies it in at sign-up, and nothing in
-- the app should be able to move it afterwards. Same reasoning as the C3
-- grants on `drivers.status`.
-- ---------------------------------------------------------------------------
revoke update on public.profiles from authenticated;
grant update (display_name, email, lang) on public.profiles to authenticated;
