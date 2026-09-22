-- Routes, stages and price bands.
--
-- The reference data the whole product is built on. Seeded by hand for the
-- pilot corridor; see supabase/seed.sql.

-- ---------------------------------------------------------------------------
-- routes
--
-- ONE ROW PER DIRECTION OF TRAVEL. Ubungo->Kimara and Kimara->Ubungo are two
-- separate rows with reversed geometry.
--
-- This is the decision that makes the matching query simple: because a route's
-- LineString runs in the direction of travel, "ahead of me" is a plain `>`
-- comparison on the 0-1 fraction along that line. A single bidirectional
-- geometry would need a heading vector and a dot product at every comparison.
-- ---------------------------------------------------------------------------
create table public.routes (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  name_sw          text not null,
  -- Human-readable direction, e.g. 'Westbound, Ubungo to Kimara Mwisho'.
  direction_label  text not null,
  -- The road itself, drawn in the direction of travel.
  geom             geography(LineString, 4326) not null,
  -- How far either side of the line still counts as "on this road", in metres.
  -- 300m covers both carriageways and the stages set back from them, without
  -- pulling in parallel streets.
  corridor_m       integer not null default 300
                     check (corridor_m between 50 and 2000),
  active           boolean not null default true,
  created_at       timestamptz not null default now()
);

comment on table public.routes is
  'One row per direction of travel. See the note in the migration.';

create index routes_geom_idx on public.routes using gist (geom);
create index routes_active_idx on public.routes (active) where active;

-- ---------------------------------------------------------------------------
-- stages
--
-- Named pickup and drop points along a route. In the MVP every pickup and
-- destination comes from this list: free-text addresses would need a geocoder,
-- which is out of scope (ARCHITECTURE D9).
-- ---------------------------------------------------------------------------
create table public.stages (
  id         uuid primary key default gen_random_uuid(),
  route_id   uuid not null references public.routes(id) on delete cascade,
  name       text not null,
  name_sw    text not null,
  geom       geography(Point, 4326) not null,
  -- Position along the route, ascending in the direction of travel. The
  -- destination list is ordered by this, never alphabetically.
  seq        integer not null check (seq >= 0),
  active     boolean not null default true,
  created_at timestamptz not null default now(),

  unique (route_id, seq),
  unique (route_id, name)
);

create index stages_geom_idx on public.stages using gist (geom);
create index stages_route_seq_idx on public.stages (route_id, seq);

-- ---------------------------------------------------------------------------
-- price_bands
--
-- What drivers on this route usually accept, per stage pair and vehicle type.
-- Hand-seeded at launch and later derived from accepted trips.
--
-- A band is a hint, never a rule: an offer below `low` still sends, with a
-- warning. The passenger sets the price.
-- ---------------------------------------------------------------------------
create table public.price_bands (
  id            uuid primary key default gen_random_uuid(),
  route_id      uuid not null references public.routes(id) on delete cascade,
  from_stage_id uuid not null references public.stages(id) on delete cascade,
  to_stage_id   uuid not null references public.stages(id) on delete cascade,
  vehicle_type  public.vehicle_type not null,
  -- Whole shillings. There are no cents in practice.
  low           integer not null check (low > 0),
  high          integer not null,
  updated_at    timestamptz not null default now(),

  constraint band_is_ordered check (high >= low),
  constraint band_goes_somewhere check (from_stage_id <> to_stage_id),
  unique (from_stage_id, to_stage_id, vehicle_type)
);

create index price_bands_lookup_idx
  on public.price_bands (from_stage_id, to_stage_id, vehicle_type);
