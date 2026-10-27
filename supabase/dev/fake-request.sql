-- Send a passenger request by hand. Development only.
--
-- WHY THIS EXISTS: the driver feed (C9) shows requests, and the screen that
-- creates them is the passenger's `pHome` at C8. Until that is built, this is
-- how you put something in a driver's feed -- and it stays useful afterwards
-- for testing the feed without a second phone.
--
-- NOT A MIGRATION AND NOT A SEED. It writes rows that look like real
-- passenger traffic, so it does not belong anywhere that runs automatically.
-- Paste it into the SQL editor of a DEV project.
--
--   1. Edit the three settings below.
--   2. Run it. A request appears in the feed of every approved driver who is
--      online, heading the same way, with a seat free, and behind the pickup.
--   3. Run `supabase/dev/fake-request-cleanup.sql` when you are done.

-- ===========================================================================
-- SETTINGS
-- ===========================================================================
-- NOTE THE COMMENT PLACEMENT. `\set` takes the whole rest of the line, so a
-- trailing `-- like this` becomes part of the value -- with the spaces
-- stripped, which is how 'Shekilango' quietly became
-- 'Shekilango--wherethepassengeriswaiting' and matched no stage at all.
-- Keep every note above its setting.

-- 'Westbound' (towards Kimara Mwisho) or 'Eastbound' (towards Ubungo).
\set direction 'Westbound'

-- Where the passenger is waiting.
\set pickup 'Shekilango'

-- Where they are going. Must be further along the route than the pickup.
\set dropoff 'Kimara Mwisho'

-- TSh, per seat.
\set price 1500

-- Who it is from.
--
-- A passenger may hold only one open request at a time -- there is a unique
-- index on it -- so to fill a feed with three cards, run this three times
-- changing the LAST DIGIT each time. The cleanup script removes all of them.
\set passenger '0de00de0-0000-4000-8000-000000000001'

-- 'bajaj' or 'boda'. Has to match the vehicle on the driver's record, or no
-- feed will show it.
\set vehicle 'bajaj'

-- In the Supabase SQL editor \set is not available. Replace the four
-- :'name' references below with literals instead, or run this file with
-- psql, which supports it:
--
--   psql "$DATABASE_URL" -f supabase/dev/fake-request.sql

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- A passenger to attribute it to.
--
-- A fixed id, so running this twice reuses the same one and the cleanup
-- script can find it. The `0de00de0` prefix is deliberate: every prefix the
-- SQL suite uses is listed in its own files, and `dddddddd` is one the
-- concurrency test deletes by pattern -- which would have quietly removed
-- this passenger every time the suite ran against the same database. Inserted into `auth.users` directly, which the service
-- role may do and which fires the `handle_new_user` trigger -- so a profile
-- appears exactly as it would for a real sign-up.
--
-- It is NOT a usable login: there is no identity row, so nobody can sign in
-- as this user. It is a row with a phone number, which is all a request
-- needs.
--
-- Deliberately not your own account. A driver does not appear in their own
-- feed -- see the note on `match_requests_for_session` -- so attributing the
-- request to yourself would file it correctly and show you nothing.
-- ---------------------------------------------------------------------------
insert into auth.users (id, phone)
values (
  :'passenger',
  -- A number derived from the id, so several dev passengers do not collide
  -- on the unique phone column.
  '+2557000000' || right(:'passenger', 2)
)
on conflict (id) do nothing;

update public.profiles
   set display_name = 'Dev passenger ' || right(:'passenger', 2)
 where id = :'passenger';

-- One open request per passenger, by unique index. Cancelling the previous
-- one is what the passenger would do, and it makes this script re-runnable
-- instead of failing on a constraint the second time.
update public.ride_requests
   set status = 'cancelled'
 where passenger_id = :'passenger' and status = 'open';

-- ---------------------------------------------------------------------------
-- The request.
-- ---------------------------------------------------------------------------
insert into public.ride_requests
  (passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
   vehicle_type, offer_price)
select
  :'passenger',
  r.id,
  ps.geom,
  ps.id,
  ds.id,
  :'vehicle',
  :price
from public.routes r
join public.stages ps on ps.route_id = r.id and ps.name = :'pickup'
join public.stages ds on ds.route_id = r.id and ds.name = :'dropoff'
where r.direction_label = :'direction'
  and r.active
  -- The destination has to be further along than the pickup, or the request
  -- describes a trip backwards and no feed will ever match it.
  and ds.seq > ps.seq;

-- ---------------------------------------------------------------------------
-- What was created, and who can see it.
--
-- If the request is there and the feed is empty, this says which condition is
-- failing rather than leaving you guessing. The commonest answer by far is
-- that nobody is online: a session ends when the driver taps Go offline, and
-- `close_abandoned_sessions` ends it after 30 minutes without a position.
-- ---------------------------------------------------------------------------
select
  ps.name   as waiting_at,
  de.name   as going_to,
  rr.offer_price,
  rr.vehicle_type,
  rr.expires_at - now() as expires_in
from public.ride_requests rr
join public.stages ps on ps.id = rr.pickup_stage_id
join public.stages de on de.id = rr.dest_stage_id
where rr.passenger_id::text like '0de00de0-%'
  and rr.status = 'open'
order by rr.created_at desc;

select
  coalesce(d.plate, '(nobody online)')            as driver,
  dest.name                                        as heading_to,
  ds.seats_free,
  case
    when ds.id is null                        then 'NOBODY IS ONLINE -- go online in the driver app first'
    when d.status <> 'approved'               then 'driver is not approved'
    when ds.route_id <> rr.route_id           then 'heading the other way'
    when ds.vehicle_type <> rr.vehicle_type   then 'wrong vehicle type for this request'
    when ds.seats_free = 0                    then 'no seats free'
    when rr.expires_at <= now()               then 'the request has expired'
    when not exists (
      select 1 from public.match_requests_for_session(ds.id)
       where request_id = rr.id
    )                                         then 'behind the driver, or past where they stop'
    else 'SHOULD SEE IT'
  end                                             as verdict
from public.ride_requests rr
left join public.driver_sessions ds on ds.status = 'online'
left join public.drivers d   on d.profile_id = ds.driver_id
left join public.stages dest on dest.id = ds.dest_stage_id
where rr.passenger_id::text like '0de00de0-%'
  and rr.status = 'open'
order by verdict, driver;
