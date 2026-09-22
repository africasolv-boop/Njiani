-- One racing driver. Takes :driver and :hold (seconds to hold the row lock).
\set ON_ERROR_STOP on
begin;
select set_config('njiani.test_uid', :'driver', true);
select ok, reason from public.accept_ride_request(
  '22222222-0000-4000-8000-000000000001',
  :'session'
);
select pg_sleep(:hold);
commit;
