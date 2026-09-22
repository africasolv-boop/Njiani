-- What the database must look like after exactly one driver won.
\set ON_ERROR_STOP on

create or replace function pg_temp.check(
  p_label text, p_actual anyelement, p_expected anyelement
) returns void language plpgsql as $$
begin
  if p_actual is distinct from p_expected then
    raise exception 'FAIL  %  expected % got %', p_label, p_expected, p_actual;
  end if;
  raise notice 'ok    %', p_label;
end $$;

select pg_temp.check('the request is claimed exactly once',
  (select count(*)::integer from public.ride_requests
    where id = '22222222-0000-4000-8000-000000000001' and status = 'claimed'), 1);

select pg_temp.check('exactly one seat exists',
  (select count(*)::integer from public.trip_seats
    where request_id = '22222222-0000-4000-8000-000000000001'), 1);

select pg_temp.check('exactly one driver lost a seat',
  (select count(*)::integer from public.driver_sessions where seats_free = 2), 1);

select pg_temp.check('the other driver kept all three',
  (select count(*)::integer from public.driver_sessions where seats_free = 3), 1);

select pg_temp.check('the agreed price was copied onto the seat',
  (select price from public.trip_seats
    where request_id = '22222222-0000-4000-8000-000000000001'), 1500);

select pg_temp.check('the winning seat belongs to the winning session',
  (select ts.session_id = ds.id
     from public.trip_seats ts
     join public.driver_sessions ds on ds.driver_id = ts.driver_id
    where ts.request_id = '22222222-0000-4000-8000-000000000001'), true);
