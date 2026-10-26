-- Driver verification: review, re-submission, and live status. Component C6.
--
-- `drivers.status` is the only thing standing between an unchecked licence and
-- a passenger getting into a stranger's vehicle, so the C3 grants hold the
-- column back from `authenticated` entirely. That is correct, and it leaves
-- two things that still have to happen:
--
--   1. An admin has to be able to move it, with the invariants enforced in
--      one place rather than remembered.
--   2. A rejected driver has to be able to get back into the queue by
--      replacing the one thing that was wrong -- which means moving `status`
--      from 'rejected' back to 'pending', which they cannot write.
--
-- Both are `security definer` functions, because that is exactly what a
-- definer function is for: a narrow, audited hole through a privilege the
-- caller does not otherwise have.

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- 1. review_driver -- the admin decision
--
-- Every rejection carries a reason. The design is explicit that an empty
-- rejection must never ship: a driver at a stage reading "Rejected" with no
-- reason has nothing to act on, and will either reinstall the app or give up.
-- The table has a CHECK that enforces it too; this raises a sentence a person
-- can read instead of a constraint name.
-- ---------------------------------------------------------------------------
create or replace function public.review_driver(
  p_driver uuid,
  p_status public.driver_status,
  p_reason text default null
)
returns public.drivers
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_driver public.drivers;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  -- Who may call this.
  --
  -- A signed-in caller must have an `admins` row. A caller with no JWT at all
  -- is the service role -- an Edge Function, the admin web at C16, or the SQL
  -- editor -- which already bypasses RLS and could do this with a plain
  -- UPDATE; what it gets from coming through here is the checks below. EXECUTE
  -- is revoked from `anon` at the bottom of this file, so an unauthenticated
  -- request cannot reach either path.
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'only an admin may review a driver'
      using errcode = '42501';
  end if;

  if p_status = 'pending' then
    raise exception 'review_driver decides a review; use resubmit_driver_licence to re-queue'
      using errcode = '22023';
  end if;

  if p_status = 'rejected' and v_reason is null then
    raise exception 'a rejection must say what to fix'
      using errcode = '22023';
  end if;

  update public.drivers
     set status           = p_status,
         -- Cleared on anything but a rejection. A stale reason sitting on an
         -- approved driver would show up on their screen the next time one of
         -- these screens read the row.
         rejection_reason = case when p_status = 'rejected' then v_reason end,
         reviewed_at      = now(),
         reviewed_by      = auth.uid()
   where profile_id = p_driver
  returning * into v_driver;

  if v_driver.profile_id is null then
    raise exception 'no driver application for %', p_driver
      using errcode = 'P0002';
  end if;

  return v_driver;
end;
$$;

comment on function public.review_driver(uuid, public.driver_status, text) is
  'C6. The admin decision on a driver application. Rejections require a reason.';

-- ---------------------------------------------------------------------------
-- 2. resubmit_driver_licence -- back into the queue
--
-- The one transition a driver needs and cannot write: 'rejected' -> 'pending'.
--
-- Scoped to a rejected row on purpose. A driver whose application is still
-- pending can already replace the photo with a plain UPDATE -- `licence_path`
-- is in the C3 update grant -- and does not need a privileged function to do
-- it. This exists only for the column they are not allowed to touch.
--
-- "Re-submission does not reset the other checks" (design, dRejected): the
-- vehicle, plate and colour are left exactly as they were, and the phone
-- number was verified at C4. Only the photo and the status move.
-- ---------------------------------------------------------------------------
create or replace function public.resubmit_driver_licence(p_licence_path text)
returns public.driver_status
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_status public.driver_status;
  v_path   text := nullif(trim(coalesce(p_licence_path, '')), '');
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  if v_path is null then
    raise exception 'a licence path is required' using errcode = '22023';
  end if;

  -- The path has to be inside the caller's own folder, matching the storage
  -- policy. Without this check a driver could point their row at another
  -- driver's photo and be approved on someone else's licence.
  if split_part(v_path, '/', 1) <> auth.uid()::text then
    raise exception 'a licence path must be inside your own folder'
      using errcode = '42501';
  end if;

  update public.drivers
     set licence_path     = v_path,
         status           = 'pending',
         rejection_reason = null,
         reviewed_at      = null,
         reviewed_by      = null
   where profile_id = auth.uid()
     and status = 'rejected'
  returning status into v_status;

  if v_status is null then
    -- Covers both "no application" and "not rejected". One message, because
    -- the only caller is the rejection screen, which got there by reading a
    -- rejected row -- so either case means the row moved underneath it, and
    -- re-reading is the answer to both.
    raise exception 'no rejected application to re-submit'
      using errcode = 'P0002';
  end if;

  return v_status;
end;
$$;

comment on function public.resubmit_driver_licence(text) is
  'C6. Moves a rejected driver back to pending with a replaced photo. The one '
  'status transition a driver may make.';

-- ---------------------------------------------------------------------------
-- Who may execute these.
--
-- Postgres grants EXECUTE to `public` by default, which would let `anon` call
-- both. Revoke, then grant deliberately.
-- ---------------------------------------------------------------------------
revoke execute on function
  public.review_driver(uuid, public.driver_status, text),
  public.resubmit_driver_licence(text)
  from public;

grant execute on function public.review_driver(uuid, public.driver_status, text)
  to authenticated, service_role;
grant execute on function public.resubmit_driver_licence(text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Live status
--
-- "A driver should never have to reinstall to discover they were approved"
-- (design, dPending). A driver submits at a stage, closes the app, and comes
-- back; the pending screen subscribes to their own row so an approval lands
-- without a refresh, and polls as a fallback for a dropped socket.
--
-- RLS applies to realtime, so `drivers_read_own` means a driver is sent
-- changes to their own row and nobody else's.
--
-- The publication is created by Supabase; created here if absent so the same
-- migration applies to a plain Postgres. Replica identity is left at the
-- primary key: the screen needs the new status, not the old one.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;

  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'drivers'
  ) then
    alter publication supabase_realtime add table public.drivers;
  end if;
end
$$;
