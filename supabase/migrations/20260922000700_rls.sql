-- Row Level Security.
--
-- Every table has RLS on. Two rules carry most of the weight:
--
--   1. A driver holds NO read policy on ride_requests. They read matches only
--      through match_requests_for_session(), which is SECURITY DEFINER and
--      scoped to their own online session. So a driver cannot enumerate the
--      passenger table, cannot see requests outside their corridor, and cannot
--      see anything at all while offline.
--
--   2. A driver cannot write drivers.status. That column is the only thing
--      between an unchecked licence and a passenger getting into a stranger's
--      vehicle. It is enforced with column-level privileges, because RLS
--      policies operate on rows and cannot protect a single column.

-- ---------------------------------------------------------------------------
-- Admins
--
-- An explicit table rather than a JWT claim: who can approve a driver should
-- be a row someone can look at and revoke, not a token that was minted once.
-- ---------------------------------------------------------------------------
create table public.admins (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  added_at   timestamptz not null default now(),
  note       text
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where profile_id = auth.uid());
$$;

alter table public.routes            enable row level security;
alter table public.stages            enable row level security;
alter table public.price_bands       enable row level security;
alter table public.profiles          enable row level security;
alter table public.drivers           enable row level security;
alter table public.driver_sessions   enable row level security;
alter table public.ride_requests     enable row level security;
alter table public.trip_seats        enable row level security;
alter table public.ratings           enable row level security;
alter table public.admins            enable row level security;

-- ---------------------------------------------------------------------------
-- Reference data: readable by anyone signed in, writable only by an admin.
-- Price bands are hand-seeded, so the write path is deliberately narrow.
-- ---------------------------------------------------------------------------
create policy routes_read on public.routes
  for select to authenticated using (active);
create policy routes_admin on public.routes
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy stages_read on public.stages
  for select to authenticated using (active);
create policy stages_admin on public.stages
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy price_bands_read on public.price_bands
  for select to authenticated using (true);
create policy price_bands_admin on public.price_bands
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- profiles: your own row, and nobody else's.
-- ---------------------------------------------------------------------------
create policy profiles_read_own on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- drivers: your own row. The status columns are protected below by GRANT.
-- ---------------------------------------------------------------------------
create policy drivers_read_own on public.drivers
  for select to authenticated
  using (profile_id = auth.uid() or public.is_admin());
create policy drivers_insert_own on public.drivers
  for insert to authenticated with check (profile_id = auth.uid());
create policy drivers_update_own on public.drivers
  for update to authenticated
  using (profile_id = auth.uid() or public.is_admin())
  with check (profile_id = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------------
-- driver_sessions: your own sessions only. Passengers never read these -- the
-- count of drivers who can see an offer comes from a function, not a table.
-- ---------------------------------------------------------------------------
create policy sessions_own on public.driver_sessions
  for all to authenticated
  using (driver_id = auth.uid() or public.is_admin())
  with check (driver_id = auth.uid());

-- ---------------------------------------------------------------------------
-- ride_requests: the passenger who made it. NO DRIVER POLICY -- see the note
-- at the top of this file. Adding one here would undo the whole model.
-- ---------------------------------------------------------------------------
create policy requests_own on public.ride_requests
  for all to authenticated
  using (passenger_id = auth.uid() or public.is_admin())
  with check (passenger_id = auth.uid());

-- ---------------------------------------------------------------------------
-- trip_seats: the passenger on the seat and the driver holding it. This is
-- also where the two sides first learn each other's phone number, and only
-- for this seat.
-- ---------------------------------------------------------------------------
create policy seats_read_party on public.trip_seats
  for select to authenticated
  using (
    passenger_id = auth.uid()
    or driver_id = auth.uid()
    or public.is_admin()
  );
create policy seats_update_party on public.trip_seats
  for update to authenticated
  using (passenger_id = auth.uid() or driver_id = auth.uid())
  with check (passenger_id = auth.uid() or driver_id = auth.uid());

-- ---------------------------------------------------------------------------
-- ratings: written by the passenger who took the trip, read by both parties.
-- ---------------------------------------------------------------------------
create policy ratings_read_party on public.ratings
  for select to authenticated
  using (
    exists (
      select 1 from public.trip_seats ts
      where ts.id = trip_seat_id
        and (ts.passenger_id = auth.uid() or ts.driver_id = auth.uid())
    )
    or public.is_admin()
  );
create policy ratings_insert_passenger on public.ratings
  for insert to authenticated
  with check (
    exists (
      select 1 from public.trip_seats ts
      where ts.id = trip_seat_id and ts.passenger_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- admins: readable only by admins. A list of who can approve drivers is not
-- something every signed-in user needs.
-- ---------------------------------------------------------------------------
create policy admins_read on public.admins
  for select to authenticated using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Column privileges.
--
-- RLS cannot protect a single column, so the verification columns are held
-- back with GRANT. A driver may edit their vehicle details; only an admin,
-- acting through the service role or an Edge Function, may move `status`.
-- ---------------------------------------------------------------------------
revoke all on public.drivers from authenticated;
grant select on public.drivers to authenticated;
grant insert (profile_id, vehicle_type, plate, colour, licence_path)
  on public.drivers to authenticated;
grant update (vehicle_type, plate, colour, licence_path)
  on public.drivers to authenticated;

-- Seat state is advanced through the release function and the driver's own
-- picked-up / dropped-off taps; price is fixed at claim time and must never
-- move afterwards.
revoke update (price, request_id, session_id, driver_id, passenger_id)
  on public.trip_seats from authenticated;
