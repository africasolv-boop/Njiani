-- The moment after a seat is claimed. Component C10.
--
-- `accept_ride_request()` has settled the race since C3. What was missing is
-- the other side of it: a passenger whose request has just been taken needs
-- to know who is coming, and the one piece of that which the security model
-- otherwise forbids is the phone number.
--
-- THE PHONE RULE (ARCHITECTURE §8): numbers are revealed to each side only
-- once a seat is claimed, and only for that seat. `profiles_read_own` means a
-- passenger cannot read a driver's row at all, which is right — a driver's
-- number is not public, and a feed full of them would be a directory. So the
-- reveal is a `security definer` function narrow enough to state in a
-- sentence: it returns the other party's number for a LIVE seat the caller is
-- on, and nothing otherwise.

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- 1. The passenger's live seat
--
-- Everything `pMatched` shows, in one call: who is coming, in what, for how
-- much, and how far away they are.
--
-- `metres_away` is straight-line, from the driver's last reported position to
-- the pickup. The screen turns it into minutes at 18 km/h (D8) and will take
-- a real road distance from OSRM at C14. Null when the driver has not
-- reported a position, which the screen says rather than guessing.
-- ---------------------------------------------------------------------------
create or replace function public.current_trip_seat()
returns table (
  seat_id        uuid,
  state          public.seat_state,
  price          integer,
  claimed_at     timestamptz,
  pickup_name    text,
  pickup_name_sw text,
  dest_name      text,
  dest_name_sw   text,
  driver_name    text,
  -- Revealed here and nowhere else. See the note at the top of this file.
  driver_phone   text,
  plate          text,
  colour         text,
  vehicle_type   public.vehicle_type,
  rating         numeric,
  trips_count    integer,
  seats_taken    integer,
  metres_away    double precision
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    ts.id,
    ts.state,
    ts.price,
    ts.claimed_at,
    ps.name,
    ps.name_sw,
    de.name,
    de.name_sw,
    dp.display_name,
    dp.phone,
    d.plate,
    d.colour,
    d.vehicle_type,
    d.rating,
    d.trips_count,
    -- How many other people are already in the vehicle. The design calls for
    -- it by name: a shared bajaj is not a surprise anyone should get on
    -- arrival.
    (ds.seats_total - ds.seats_free)::integer,
    st_distance(ds.last_pos, rr.pickup)
  from public.trip_seats ts
  join public.ride_requests rr  on rr.id = ts.request_id
  join public.driver_sessions ds on ds.id = ts.session_id
  join public.drivers d          on d.profile_id = ts.driver_id
  join public.profiles dp        on dp.id = ts.driver_id
  left join public.stages ps     on ps.id = rr.pickup_stage_id
  join public.stages de          on de.id = rr.dest_stage_id
  where ts.passenger_id = auth.uid()
    -- Live only. A dropped or cancelled seat is history, and its phone
    -- number stops being anybody's business the moment the trip ends.
    and ts.state in ('claimed', 'aboard');
$$;

comment on function public.current_trip_seat() is
  'C10. The passenger''s live seat, with the driver''s number -- revealed only '
  'for a live seat, and only to the passenger on it.';

-- ---------------------------------------------------------------------------
-- 2. The passenger withdrawing after a claim
--
-- "Cancel is free until the driver arrives. MVP has no penalty either way"
-- (design, pMatched). `release_trip_seat` already frees the seat and puts the
-- request back on the road; this is the passenger's doorway to it, scoped to
-- their own seat.
--
-- Not reopened: a passenger who changes their mind is not still waiting, and
-- re-offering their request to the road would send a second driver to
-- somebody who has gone.
-- ---------------------------------------------------------------------------
create or replace function public.cancel_my_seat()
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_seat uuid;
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  select id into v_seat
  from public.trip_seats
  where passenger_id = auth.uid() and state in ('claimed', 'aboard')
  limit 1;

  if v_seat is null then
    return false;
  end if;

  return (select ok from public.release_trip_seat(v_seat, false));
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Telling the passenger, without them tapping
--
-- `trip_seats` carries a read policy for both parties -- unlike
-- `ride_requests`, which drivers may not read at all -- so this one really
-- can be a subscription rather than a doorbell. RLS applies to realtime, so a
-- passenger is sent changes to their own seats and nobody else's.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;

  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public' and tablename = 'trip_seats'
  ) then
    alter publication supabase_realtime add table public.trip_seats;
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Who may call these.
-- ---------------------------------------------------------------------------
revoke execute on function
  public.current_trip_seat(),
  public.cancel_my_seat()
  from public;

grant execute on function
  public.current_trip_seat(),
  public.cancel_my_seat()
  to authenticated;
