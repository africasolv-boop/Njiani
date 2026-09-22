-- Enumerated types.
--
-- Enums rather than text + check: these values are read by the apps, by the
-- matching function and by the admin queue, and a typo in any of them should
-- fail at write time rather than silently match nothing.

-- A bajaj is a three-wheeler; a boda boda is a motorcycle. The distinction
-- decides how many seats exist, which is a physical fact, not a setting.
create type public.vehicle_type as enum ('bajaj', 'boda');

-- Driver verification state. Only an admin may move this off 'pending'.
create type public.driver_status as enum (
  'pending',
  'approved',
  'rejected',
  'suspended'
);

-- A passenger's request for a seat.
--   open      : visible to matching drivers
--   claimed   : a driver won the atomic claim
--   expired   : nobody took it inside the window. Kept, not deleted -- this is
--               the pricing dataset (ARCHITECTURE §7)
--   cancelled : the passenger withdrew it
create type public.request_status as enum (
  'open',
  'claimed',
  'expired',
  'cancelled'
);

-- One seat on one trip. Each seat is its own row with its own price, never one
-- trip carrying three passengers.
create type public.seat_state as enum (
  'claimed',
  'aboard',
  'dropped',
  'cancelled'
);
