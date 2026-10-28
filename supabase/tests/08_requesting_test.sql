-- Tests for asking for a seat. Component C8.
--
-- The claim: a request that is written is a request that can be matched. The
-- failure this guards against is not an error message -- it is a row that
-- saves perfectly and then never appears in any feed, because the client was
-- allowed to decide something it had no business deciding.

\set ON_ERROR_STOP on
set search_path = public, extensions;
begin;

create or replace function pg_temp.check(
  p_label text, p_actual anyelement, p_expected anyelement
) returns void language plpgsql as $$
begin
  if p_actual is distinct from p_expected then
    raise exception 'FAIL  %  expected % got %', p_label, p_expected, p_actual;
  end if;
  raise notice 'ok    %', p_label;
end $$;

create or replace function pg_temp.errcode(p_sql text)
returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception
  when others then return sqlstate;
end $$;

insert into auth.users (id, phone) values
  ('c8000000-0000-4000-8000-000000000001', '+255754000071'),  -- passenger
  ('c8000000-0000-4000-8000-000000000002', '+255712000071');  -- driver

insert into public.drivers
  (profile_id, vehicle_type, plate, colour, licence_path, status)
values ('c8000000-0000-4000-8000-000000000002', 'bajaj', 'T 881 AAA', 'Blue',
        'c8000000-0000-4000-8000-000000000002/licence.jpg', 'approved');

create temporary table f (k text primary key, v uuid) on commit drop;
insert into f select 'west', id from public.routes where direction_label = 'Westbound';
insert into f select 'east', id from public.routes where direction_label = 'Eastbound';
insert into f select 'ubungo', id from public.stages
  where name = 'Ubungo Mataa' and route_id = (select v from f where k = 'west');
insert into f select 'shekilango', id from public.stages
  where name = 'Shekilango' and route_id = (select v from f where k = 'west');
insert into f select 'mwisho', id from public.stages
  where name = 'Kimara Mwisho' and route_id = (select v from f where k = 'west');
insert into f select 'east_ubungo', id from public.stages
  where name = 'Ubungo Mataa' and route_id = (select v from f where k = 'east');
grant select on f to authenticated;

-- ===========================================================================
-- The price band
-- ===========================================================================
select pg_temp.check(
  'a seeded pair has a band',
  (select low || '-' || high from public.price_band(
     (select v from f where k = 'ubungo'),
     (select v from f where k = 'mwisho'), 'bajaj')),
  '1700-2500'
);

-- Nobody offers TSh 1,137.
select pg_temp.check(
  'the middle chip is rounded to the nearest hundred',
  (select mid from public.price_band(
     (select v from f where k = 'ubungo'),
     (select v from f where k = 'mwisho'), 'bajaj')),
  2100
);

-- No row rather than a guess. A made-up band is worse than none, because a
-- passenger anchors to it.
select pg_temp.check(
  'an unpriced pair has no band, rather than an invented one',
  (select count(*)::integer from public.price_band(
     (select v from f where k = 'mwisho'),
     (select v from f where k = 'ubungo'), 'bajaj')),
  0
);

-- ===========================================================================
-- Act as the PASSENGER
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'c8000000-0000-4000-8000-000000000001', true);

-- ---------------------------------------------------------------------------
-- The four ways a request can be unmatchable, each refused before it is
-- written. None of these produces an error without the check -- they produce
-- a row that saves and then does nothing.
-- ---------------------------------------------------------------------------
select pg_temp.check(
  'a trip backwards along the road is refused',
  pg_temp.errcode(format($sql$
    select public.create_ride_request(%L, %L, 'bajaj', 1500)
  $sql$, (select v from f where k = 'mwisho'),
         (select v from f where k = 'ubungo'))),
  '22023'
);

select pg_temp.check(
  'two stages on different routes are refused',
  pg_temp.errcode(format($sql$
    select public.create_ride_request(%L, %L, 'bajaj', 1500)
  $sql$, (select v from f where k = 'ubungo'),
         (select v from f where k = 'east_ubungo'))),
  '22023'
);

select pg_temp.check(
  'going nowhere is refused',
  pg_temp.errcode(format($sql$
    select public.create_ride_request(%L, %L, 'bajaj', 1500)
  $sql$, (select v from f where k = 'ubungo'),
         (select v from f where k = 'ubungo'))),
  '22023'
);

select pg_temp.check(
  'a price of nothing is refused',
  pg_temp.errcode(format($sql$
    select public.create_ride_request(%L, %L, 'bajaj', 0)
  $sql$, (select v from f where k = 'ubungo'),
         (select v from f where k = 'mwisho'))),
  '22023'
);

-- ---------------------------------------------------------------------------
-- A good one
-- ---------------------------------------------------------------------------
select pg_temp.check(
  'a request is created, open',
  (select status::text from public.create_ride_request(
     (select v from f where k = 'ubungo'),
     (select v from f where k = 'mwisho'), 'bajaj', 1500)),
  'open'
);

-- Resolved here, not sent by the client: a pickup point that drifts off the
-- corridor is a request no feed will ever show.
select pg_temp.check(
  'the pickup point comes from the stage',
  (select st_distance(rr.pickup, s.geom) < 1
     from public.ride_requests rr, public.stages s
    where rr.passenger_id = 'c8000000-0000-4000-8000-000000000001'
      and s.id = (select v from f where k = 'ubungo')),
  true
);

select pg_temp.check(
  'the route is resolved from the pair, not supplied',
  (select route_id from public.ride_requests
    where passenger_id = 'c8000000-0000-4000-8000-000000000001'),
  (select v from f where k = 'west')
);

select pg_temp.check(
  'it expires in ten minutes, as the screen says',
  (select round(extract(epoch from (expires_at - created_at)) / 60)::integer
     from public.ride_requests
    where passenger_id = 'c8000000-0000-4000-8000-000000000001'),
  10
);

-- The price is the passenger's. Below the band is a warning on screen, not a
-- refusal here: ARCHITECTURE §7, and a rejected offer tells us more about the
-- floor than an accepted one does.
select pg_temp.check(
  'a second request is refused while one is waiting',
  pg_temp.errcode(format($sql$
    select public.create_ride_request(%L, %L, 'bajaj', 1500)
  $sql$, (select v from f where k = 'ubungo'),
         (select v from f where k = 'shekilango'))),
  '23505'
);

-- ---------------------------------------------------------------------------
-- Reading it back
-- ---------------------------------------------------------------------------
select pg_temp.check(
  'the waiting request comes back with its place names',
  (select pickup_name || ' -> ' || dest_name from public.current_ride_request()),
  'Ubungo Mataa -> Kimara Mwisho'
);

-- ---------------------------------------------------------------------------
-- Withdrawing it
-- ---------------------------------------------------------------------------
select pg_temp.check('cancelling withdraws exactly one',
  public.cancel_ride_request(), 1);

select pg_temp.check('nothing is waiting afterwards',
  (select count(*)::integer from public.current_ride_request()), 0);

-- Kept, not deleted: an unmatched request carries its offer, its destination
-- and its time of day, which is the pricing dataset (ARCHITECTURE §7).
select pg_temp.check(
  'the row survives, cancelled and stamped',
  (select status::text || ' ' || (cancelled_at is not null)::text
     from public.ride_requests
    where passenger_id = 'c8000000-0000-4000-8000-000000000001'),
  'cancelled true'
);

select pg_temp.check('cancelling twice withdraws nothing',
  public.cancel_ride_request(), 0);

select pg_temp.check(
  'and a new request can be made once the old one is gone',
  (select offer_price from public.create_ride_request(
     (select v from f where k = 'ubungo'),
     (select v from f where k = 'shekilango'), 'boda', 600)),
  600
);

reset role;

-- ===========================================================================
-- The whole point: the driver can see it
--
-- Every check above is about a request being matchable. This is the one that
-- says it actually is.
-- ===========================================================================
insert into public.driver_sessions
  (id, driver_id, route_id, dest_stage_id, vehicle_type, seats_total,
   seats_free, last_pos, last_pos_at)
values ('c8111111-0000-4000-8000-000000000001',
        'c8000000-0000-4000-8000-000000000002',
        (select v from f where k = 'west'),
        (select v from f where k = 'mwisho'),
        'boda', 1, 1,
        (select geom from public.stages
          where id = (select v from f where k = 'ubungo')),
        now());

set local role authenticated;
select set_config('njiani.test_uid', 'c8000000-0000-4000-8000-000000000002', true);

-- The boda request made above, seen by a boda rider heading the same way.
select pg_temp.check(
  'a request made through the function reaches a driver feed',
  (select pickup_stage || ' -> ' || dest_stage || ' @ ' || offer_price
     from public.match_requests_for_session(
       'c8111111-0000-4000-8000-000000000001')),
  'Ubungo Mataa -> Shekilango @ 600'
);

-- The tolerance that made the assertion above pass, pinned so nobody tunes it
-- away. A passenger at the stage the driver is pulling out of is the most
-- likely match there is, and `pickup_t > driver_t` excluded them over a few
-- metres of GPS noise.
select pg_temp.check(
  'a passenger just behind the driver is still offered',
  (select count(*)::integer from public.match_requests_for_session(
     'c8111111-0000-4000-8000-000000000001', 100)),
  1
);

select pg_temp.check(
  'but not one a long way behind -- that would mean turning round',
  (select count(*)::integer from public.match_requests_for_session(
     'c8111111-0000-4000-8000-000000000001', 0)),
  0
);

reset role;

-- ===========================================================================
-- Nobody else's
-- ===========================================================================
set local role authenticated;
select set_config('njiani.test_uid', 'c8000000-0000-4000-8000-000000000002', true);

select pg_temp.check(
  'a driver cannot read the passenger''s waiting request',
  (select count(*)::integer from public.current_ride_request()),
  0
);

select pg_temp.check(
  'a driver cannot cancel it either',
  public.cancel_ride_request(),
  0
);

reset role;

select pg_temp.check(
  'and it is still open',
  (select count(*)::integer from public.ride_requests
    where passenger_id = 'c8000000-0000-4000-8000-000000000001'
      and status = 'open'),
  1
);

-- ===========================================================================
-- Exactly one matching function
--
-- `create or replace` only replaces a function with the same signature, so
-- adding the tolerance parameter created a SECOND one beside the original and
-- every one-argument call started failing with "is not unique" -- which is to
-- say, every driver feed. Caught by rebuilding the database from scratch,
-- which is the only way the duplicate appears.
-- ===========================================================================
-- Stated for the whole schema rather than for the one function that broke,
-- because nothing about this is specific to it: any migration that adds a
-- parameter to an existing function leaves two behind, and the symptom is a
-- call that worked yesterday failing on a word nobody searched for.
select pg_temp.check(
  'no function in public is defined twice',
  (select coalesce(string_agg(p.proname || ' x' || c, ', '), 'none')
     from (select proname, count(*) as c
             from pg_proc p
             join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public'
            group by proname
           having count(*) > 1) p),
  'none'
);

rollback;
