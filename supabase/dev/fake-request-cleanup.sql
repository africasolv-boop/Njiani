-- Remove everything `fake-request.sql` created. Development only.
--
-- Safe to run repeatedly, and safe to run on a project that never had any.
-- Scoped to the `0de00de0-` id prefix the helper uses, so it cannot touch a
-- real passenger's requests. That prefix is not one the SQL suite uses --
-- `dddddddd-` would have been deleted by the concurrency test's own cleanup.

set search_path = public, extensions;

-- Seats first: trip_seats references the requests.
delete from public.trip_seats
 where passenger_id::text like '0de00de0-%';

delete from public.ride_requests
 where passenger_id::text like '0de00de0-%';

-- The profile goes with the user, by `on delete cascade`.
delete from auth.users
 where id::text like '0de00de0-%';

select 'dev passenger and their requests removed' as done;
