-- Scheduled work.
--
-- On Supabase, enable pg_cron from the dashboard (Database -> Extensions)
-- before this migration runs. It is created here so a local stack matches.

create extension if not exists pg_cron;

-- Expire unmatched requests every minute.
--
-- Every-minute rather than on-read: the passenger's screen has to change by
-- itself when the ten minutes are up, and a driver must never be shown a
-- request that is already dead.
select cron.schedule(
  'njiani-expire-requests',
  '* * * * *',
  $$select public.expire_stale_requests();$$
);

-- Close sessions from drivers who stopped reporting position.
--
-- A driver who closes the app mid-trip would otherwise stay "online" forever,
-- holding seats that no vehicle is coming for.
create or replace function public.close_abandoned_sessions()
returns integer
language sql
security definer
set search_path = public
as $$
  with closed as (
    update public.driver_sessions
       set status = 'offline', ended_at = now()
     where status = 'online'
       and coalesce(last_pos_at, went_online_at) < now() - interval '30 minutes'
    returning 1
  )
  select count(*)::integer from closed;
$$;

select cron.schedule(
  'njiani-close-abandoned-sessions',
  '*/5 * * * *',
  $$select public.close_abandoned_sessions();$$
);

-- Purge raw position traces after 30 days (PDPA 2022, ARCHITECTURE §12).
-- Trip records are retained; only the location trail goes.
create or replace function public.purge_old_positions()
returns integer
language sql
security definer
set search_path = public
as $$
  with purged as (
    update public.driver_sessions
       set last_pos = null
     where last_pos is not null
       and went_online_at < now() - interval '30 days'
    returning 1
  )
  select count(*)::integer from purged;
$$;

select cron.schedule(
  'njiani-purge-positions',
  '17 3 * * *',
  $$select public.purge_old_positions();$$
);
