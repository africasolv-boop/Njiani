-- Tests for the live feed's signal. Component C9.
--
-- Two claims, and the second matters more than the first:
--
--   1. A driver's feed is told when something changed, without the signal
--      carrying anything a driver has no policy to read.
--   2. Nothing about that signal can stop a passenger's request being
--      written. A broadcast is a convenience; a request is the product.

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

-- ---------------------------------------------------------------------------
-- Fixtures: two drivers heading different ways, and two passengers.
-- ---------------------------------------------------------------------------
insert into auth.users (id, phone) values
  ('c9000000-0000-4000-8000-000000000001', '+255754000061'),  -- driver west
  ('c9000000-0000-4000-8000-000000000002', '+255712000061'),  -- driver east
  ('c9000000-0000-4000-8000-000000000003', '+255713000061'),  -- passenger
  ('c9000000-0000-4000-8000-000000000004', '+255715000061');  -- passenger

insert into public.drivers
  (profile_id, vehicle_type, plate, colour, licence_path, status)
values
  ('c9000000-0000-4000-8000-000000000001', 'bajaj', 'T 991 AAA', 'Blue',
   'c9000000-0000-4000-8000-000000000001/licence.jpg', 'approved'),
  ('c9000000-0000-4000-8000-000000000002', 'bajaj', 'T 992 BBB', 'Green',
   'c9000000-0000-4000-8000-000000000002/licence.jpg', 'approved');

create temporary table f (k text primary key, v uuid) on commit drop;
insert into f select 'west', id from public.routes where direction_label = 'Westbound';
insert into f select 'east', id from public.routes where direction_label = 'Eastbound';
insert into f select 'ubungo', id from public.stages
  where name = 'Ubungo Mataa' and route_id = (select v from f where k = 'west');
insert into f select 'shekilango', id from public.stages
  where name = 'Shekilango' and route_id = (select v from f where k = 'west');
insert into f select 'kibo', id from public.stages
  where name = 'Kibo' and route_id = (select v from f where k = 'west');
insert into f select 'mwisho', id from public.stages
  where name = 'Kimara Mwisho' and route_id = (select v from f where k = 'west');
insert into f select 'east_mwisho', id from public.stages
  where name = 'Kimara Mwisho' and route_id = (select v from f where k = 'east');
grant select on f to authenticated;

-- Both drivers online: one westbound, one eastbound.
insert into public.driver_sessions
  (id, driver_id, route_id, dest_stage_id, vehicle_type, seats_total,
   seats_free, last_pos, last_pos_at)
values
  ('c9111111-0000-4000-8000-000000000001',
   'c9000000-0000-4000-8000-000000000001',
   (select v from f where k = 'west'), (select v from f where k = 'mwisho'),
   'bajaj', 3, 3,
   (select geom from public.stages where id = (select v from f where k = 'ubungo')),
   now()),
  ('c9111111-0000-4000-8000-000000000002',
   'c9000000-0000-4000-8000-000000000002',
   (select v from f where k = 'east'), (select v from f where k = 'east_mwisho'),
   'bajaj', 3, 3,
   (select geom from public.stages where id = (select v from f where k = 'ubungo')),
   now());

-- ===========================================================================
-- The nudge
-- ===========================================================================
delete from realtime.sent;

insert into public.ride_requests
  (id, passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
   vehicle_type, offer_price)
values ('c9222222-0000-4000-8000-000000000001',
        'c9000000-0000-4000-8000-000000000003',
        (select v from f where k = 'west'),
        (select geom from public.stages where id = (select v from f where k = 'shekilango')),
        (select v from f where k = 'shekilango'),
        (select v from f where k = 'mwisho'),
        'bajaj', 1500);

select pg_temp.check('a new request nudges once',
  (select count(*)::integer from realtime.sent), 1);

select pg_temp.check(
  'the nudge goes to the route and vehicle topic',
  (select topic from realtime.sent),
  'feed:' || (select v from f where k = 'west')::text || ':bajaj'
);

select pg_temp.check('the topic is the one the client builds',
  (select topic from realtime.sent),
  public.route_feed_topic((select v from f where k = 'west'), 'bajaj'));

select pg_temp.check('it is a private topic',
  (select private from realtime.sent), true);

-- THE ONE THAT MATTERS. A driver holds no read policy on ride_requests, so
-- the signal must not be a way around that. If this ever starts failing, the
-- nudge has become a window.
select pg_temp.check(
  'the payload carries nothing a driver may not read',
  (select array_agg(k order by k)::text
     from realtime.sent, jsonb_object_keys(payload) k),
  '{at,route_id,vehicle_type}'
);

select pg_temp.check(
  'no price, no passenger, no destination in the payload',
  (select payload::text ~* '(price|passenger|dest|pickup|phone)'
     from realtime.sent),
  false
);

-- ---------------------------------------------------------------------------
-- Leaving `open` is also news: it is how a card disappears from every other
-- driver's feed.
-- ---------------------------------------------------------------------------
delete from realtime.sent;
update public.ride_requests set status = 'cancelled'
 where id = 'c9222222-0000-4000-8000-000000000001';

select pg_temp.check('a request leaving open nudges too',
  (select count(*)::integer from realtime.sent), 1);

-- But a change nothing can see is not news. Waking a driver's phone costs
-- them battery.
delete from realtime.sent;
update public.ride_requests set offer_price = 2000
 where id = 'c9222222-0000-4000-8000-000000000001';

select pg_temp.check('an unrelated column change does not nudge',
  (select count(*)::integer from realtime.sent), 0);

-- ===========================================================================
-- A broken broadcast must not break the product
--
-- Replace realtime.send with one that raises -- a renamed function, a
-- missing schema, a Realtime outage all look like this from in here -- and
-- the passenger's request must still be written.
-- ===========================================================================
create or replace function realtime.send(
  payload jsonb, event text, topic text, private boolean default true
) returns void language plpgsql as $$
begin
  raise exception 'realtime is down';
end $$;

select pg_temp.check(
  'a request is still written when the broadcast fails',
  pg_temp.errcode($sql$
    insert into public.ride_requests
      (id, passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
       vehicle_type, offer_price)
    select 'c9222222-0000-4000-8000-000000000002',
           'c9000000-0000-4000-8000-000000000004',
           (select v from f where k = 'west'),
           (select geom from public.stages where id = (select v from f where k = 'kibo')),
           (select v from f where k = 'kibo'),
           (select v from f where k = 'mwisho'),
           'bajaj', 1800
  $sql$),
  null
);

select pg_temp.check(
  'and it is really there',
  (select count(*)::integer from public.ride_requests
    where id = 'c9222222-0000-4000-8000-000000000002'),
  1
);

-- Put the recorder back for the rest of the file.
create or replace function realtime.send(
  payload jsonb, event text, topic text, private boolean default true
) returns void language sql as $$
  insert into realtime.sent (payload, event, topic, private)
  values (payload, event, topic, private);
$$;

-- ===========================================================================
-- Who may subscribe
--
-- Realtime checks `realtime.messages` RLS before delivering on a private
-- topic. The predicate is what is tested here; that Realtime consults it is
-- tested on a device.
-- ===========================================================================
insert into realtime.messages (topic, event, private)
values
  (public.route_feed_topic((select v from f where k = 'west'), 'bajaj'),
   'feed_changed', true),
  (public.route_feed_topic((select v from f where k = 'east'), 'bajaj'),
   'feed_changed', true);

set local role authenticated;
select set_config('njiani.test_uid', 'c9000000-0000-4000-8000-000000000001', true);

select pg_temp.check(
  'a driver sees their own route''s topic',
  (select count(*)::integer from realtime.messages),
  1
);

select pg_temp.check(
  'and only that one -- not the other direction''s',
  (select topic from realtime.messages),
  public.route_feed_topic((select v from f where k = 'west'), 'bajaj')
);

reset role;

-- Going offline ends the subscription, which is the same lifetime the feed
-- has. A phone left in a pocket should stop being woken.
update public.driver_sessions set status = 'offline', ended_at = now()
 where driver_id = 'c9000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config('njiani.test_uid', 'c9000000-0000-4000-8000-000000000001', true);

select pg_temp.check(
  'an offline driver subscribes to nothing',
  (select count(*)::integer from realtime.messages),
  0
);

select set_config('njiani.test_uid', 'c9000000-0000-4000-8000-000000000003', true);

select pg_temp.check(
  'a passenger subscribes to nothing',
  (select count(*)::integer from realtime.messages),
  0
);

select set_config('njiani.test_uid', '', true);

select pg_temp.check(
  'a signed-out client subscribes to nothing',
  (select count(*)::integer from realtime.messages),
  0
);

reset role;

-- ===========================================================================
-- The feed's order, which the design is explicit about
-- ===========================================================================
update public.ride_requests set status = 'open'
 where id = 'c9222222-0000-4000-8000-000000000001';
update public.driver_sessions set status = 'online', ended_at = null
 where driver_id = 'c9000000-0000-4000-8000-000000000001';

-- Back to being the westbound driver. `match_requests_for_session` is scoped
-- to `ds.driver_id = auth.uid()`, so the empty GUC left over from the
-- signed-out assertion above returns an empty feed -- correctly, and for a
-- reason that has nothing to do with ordering.
select set_config('njiani.test_uid', 'c9000000-0000-4000-8000-000000000001', true);

-- Shekilango is nearer than Kibo, and the Kibo passenger is offering more.
-- Nearest ahead wins: sorting a shared road by money turns it into an
-- auction, and the design says never.
select pg_temp.check(
  'nearest ahead first, not the better offer',
  (select string_agg(pickup_stage, ' > ' order by meters_ahead)
     from public.match_requests_for_session(
       'c9111111-0000-4000-8000-000000000001')),
  'Shekilango > Kibo'
);

select pg_temp.check(
  'the feed is ordered as returned, without the client sorting it',
  (select array_agg(pickup_stage)::text
     from public.match_requests_for_session(
       'c9111111-0000-4000-8000-000000000001')),
  '{Shekilango,Kibo}'
);

-- A driver is a passenger on their days off, and the request outlives the
-- mood. Claiming your own would write a trip_seats row whose driver and
-- passenger are the same person, which is not a trip.
insert into public.ride_requests
  (id, passenger_id, route_id, pickup, pickup_stage_id, dest_stage_id,
   vehicle_type, offer_price)
values ('c9222222-0000-4000-8000-000000000003',
        'c9000000-0000-4000-8000-000000000001',   -- the driver themselves
        (select v from f where k = 'west'),
        (select geom from public.stages where id = (select v from f where k = 'shekilango')),
        (select v from f where k = 'shekilango'),
        (select v from f where k = 'mwisho'),
        'bajaj', 9000);

select pg_temp.check(
  'a driver does not appear in their own feed',
  (select count(*)::integer from public.match_requests_for_session(
     'c9111111-0000-4000-8000-000000000001')
    where request_id = 'c9222222-0000-4000-8000-000000000003'),
  0
);

-- ...and the rest of the feed is untouched by it. A nine-thousand-shilling
-- offer at the nearest stage would otherwise be top of the list.
select pg_temp.check(
  'and everyone else is still there',
  (select count(*)::integer from public.match_requests_for_session(
     'c9111111-0000-4000-8000-000000000001')),
  2
);

-- And the eastbound driver sees neither: they are westbound requests.
select pg_temp.check(
  'a driver heading the other way sees none of them',
  (select count(*)::integer from public.match_requests_for_session(
     'c9111111-0000-4000-8000-000000000002')),
  0
);

rollback;
