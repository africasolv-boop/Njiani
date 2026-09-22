-- Driver sessions, ride requests, seats and ratings.

-- ---------------------------------------------------------------------------
-- driver_sessions
--
-- A driver who has declared a heading and gone online. This is the row that
-- makes Njiani not a ride-hailing app: the driver chooses a direction BEFORE
-- seeing any request, and the feed is derived from this row.
-- ---------------------------------------------------------------------------
create table public.driver_sessions (
  id             uuid primary key default gen_random_uuid(),
  driver_id      uuid not null
                   references public.drivers(profile_id) on delete cascade,
  route_id       uuid not null references public.routes(id),
  dest_stage_id  uuid not null references public.stages(id),
  vehicle_type   public.vehicle_type not null,
  seats_total    smallint not null,
  seats_free     smallint not null,
  -- Last known position. Null until the first GPS fix: a driver who has just
  -- gone online still sees the whole road ahead rather than an empty feed.
  last_pos       geography(Point, 4326),
  last_pos_at    timestamptz,
  status         text not null default 'online'
                   check (status in ('online', 'offline')),
  went_online_at timestamptz not null default now(),
  ended_at       timestamptz,

  -- Seat count is a property of the vehicle, not a setting a driver can
  -- change. A bajaj has three seats; a boda has one.
  constraint seats_match_vehicle check (
    (vehicle_type = 'bajaj' and seats_total = 3) or
    (vehicle_type = 'boda'  and seats_total = 1)
  ),
  constraint seats_free_within_total
    check (seats_free between 0 and seats_total)
);

-- One online session per driver. Changing direction ends the old session and
-- starts a new one; being online twice would double-count the seats.
create unique index driver_sessions_one_online_idx
  on public.driver_sessions (driver_id) where status = 'online';

create index driver_sessions_pos_idx
  on public.driver_sessions using gist (last_pos);
create index driver_sessions_online_idx
  on public.driver_sessions (route_id, dest_stage_id) where status = 'online';

-- ---------------------------------------------------------------------------
-- ride_requests
--
-- A passenger's offer for one seat, at a price they chose.
-- ---------------------------------------------------------------------------
create table public.ride_requests (
  id              uuid primary key default gen_random_uuid(),
  passenger_id    uuid not null
                    references public.profiles(id) on delete cascade,
  route_id        uuid not null references public.routes(id),
  pickup          geography(Point, 4326) not null,
  -- In the MVP pickup always comes from the stage list, so this is set. The
  -- column stays nullable for the v2 case of an arbitrary point on the road.
  pickup_stage_id uuid references public.stages(id),
  dest_stage_id   uuid not null references public.stages(id),
  vehicle_type    public.vehicle_type not null,
  offer_price     integer not null check (offer_price > 0),
  status          public.request_status not null default 'open',
  created_at      timestamptz not null default now(),
  -- Ten minutes, matching the copy on the request screen. pg_cron expires
  -- these; the row is kept, because an unmatched expiry with its offer and
  -- destination is the most informative pricing signal there is.
  expires_at      timestamptz not null default now() + interval '10 minutes',
  claimed_at      timestamptz,
  cancelled_at    timestamptz,

  constraint goes_somewhere_else
    check (pickup_stage_id is null or pickup_stage_id <> dest_stage_id)
);

-- A passenger can have only one open request. Two would let one person hold
-- two seats on the same road and strand whichever driver arrives second.
create unique index ride_requests_one_open_idx
  on public.ride_requests (passenger_id) where status = 'open';

create index ride_requests_pickup_idx
  on public.ride_requests using gist (pickup);
-- The matching query's hot path: open requests on a route, by vehicle.
create index ride_requests_open_idx
  on public.ride_requests (route_id, vehicle_type, expires_at)
  where status = 'open';

-- ---------------------------------------------------------------------------
-- trip_seats
--
-- One row per seat sold. Three passengers in a bajaj are three rows with three
-- prices and three states -- never one trip with three passengers, which would
-- make it impossible to drop one of them or to price them separately.
-- ---------------------------------------------------------------------------
create table public.trip_seats (
  id           uuid primary key default gen_random_uuid(),
  request_id   uuid not null
                 references public.ride_requests(id) on delete cascade,
  session_id   uuid not null
                 references public.driver_sessions(id) on delete cascade,
  driver_id    uuid not null references public.drivers(profile_id),
  passenger_id uuid not null references public.profiles(id),
  -- Copied from the request at claim time. The agreed price must not move
  -- afterwards, whatever happens to the request row.
  price        integer not null check (price > 0),
  state        public.seat_state not null default 'claimed',
  claimed_at   timestamptz not null default now(),
  aboard_at    timestamptz,
  dropped_at   timestamptz,
  cancelled_at timestamptz
);

-- At most one LIVE seat per request: a second line of defence behind the
-- atomic claim.
--
-- Partial, not a plain unique constraint. A request that was claimed and then
-- released is legitimately claimed again by the next driver, and the cancelled
-- seat stays as history. A blanket UNIQUE(request_id) would let the first
-- cancellation strand the passenger permanently -- their request would be back
-- on the road, visible to every driver, and impossible for any of them to take.
create unique index trip_seats_one_live_per_request_idx
  on public.trip_seats (request_id)
  where state <> 'cancelled';

create index trip_seats_session_idx on public.trip_seats (session_id);
create index trip_seats_driver_idx on public.trip_seats (driver_id, state);
create index trip_seats_passenger_idx on public.trip_seats (passenger_id);

-- ---------------------------------------------------------------------------
-- ratings
-- ---------------------------------------------------------------------------
create table public.ratings (
  id           uuid primary key default gen_random_uuid(),
  trip_seat_id uuid not null unique
                 references public.trip_seats(id) on delete cascade,
  stars        smallint not null check (stars between 1 and 5),
  comment      text,
  created_at   timestamptz not null default now()
);

-- One and two star ratings are the only reliable safety signal at 15 drivers,
-- so the admin view of them has its own index.
create index ratings_low_idx on public.ratings (created_at)
  where stars <= 2;
