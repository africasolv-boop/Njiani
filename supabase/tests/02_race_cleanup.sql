-- Removes the concurrency fixtures. That test commits by necessity, so it
-- cleans up explicitly rather than rolling back.
\set ON_ERROR_STOP on
delete from public.trip_seats
 where request_id = '22222222-0000-4000-8000-000000000001';
delete from public.ride_requests
 where id = '22222222-0000-4000-8000-000000000001';
delete from public.driver_sessions
 where driver_id::text like 'cccccccc%';
delete from public.drivers
 where profile_id::text like 'cccccccc%';
delete from public.profiles
 where id::text like 'cccccccc%' or id::text like 'dddddddd%';
delete from auth.users
 where id::text like 'cccccccc%' or id::text like 'dddddddd%';
