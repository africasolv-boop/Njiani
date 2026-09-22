-- Pilot corridor seed: Ubungo <-> Kimara along Morogoro Road.
--
-- ===========================================================================
-- ⚠ THE COORDINATES BELOW ARE APPROXIMATE AND MUST BE VERIFIED ON THE GROUND.
--
-- They are plausible positions along Morogoro Road, good enough to develop and
-- test against. They are NOT surveyed. A stage placed 400m from where drivers
-- and passengers actually stand will silently fall outside the 300m corridor,
-- and the matching query will return nothing while looking perfectly healthy
-- -- the worst possible failure, because it is invisible.
--
-- Before launch: stand at each stage, take a GPS reading, and replace the
-- pair here. That visit is also when the price bands get their real numbers.
-- ===========================================================================
--
-- Two route rows, one per direction of travel. See the routes migration for
-- why that is not duplication.

begin;

-- ---------------------------------------------------------------------------
-- The stage list, in westbound order. Everything else is derived from it.
-- ---------------------------------------------------------------------------
create temporary table seed_stages (
  seq     integer primary key,
  name    text not null,
  name_sw text not null,
  lon     double precision not null,
  lat     double precision not null
) on commit drop;

insert into seed_stages (seq, name, name_sw, lon, lat) values
  (0, 'Ubungo Bus Terminal', 'Stendi ya Ubungo',  39.2144, -6.7889),
  (1, 'Ubungo Mataa',        'Ubungo Mataa',      39.2073, -6.7872),
  (2, 'Shekilango',          'Shekilango',        39.1995, -6.7855),
  (3, 'Ubungo Maji',         'Ubungo Maji',       39.1917, -6.7838),
  (4, 'Riverside',           'Riverside',         39.1830, -6.7818),
  (5, 'Kibo',                'Kibo',              39.1740, -6.7796),
  (6, 'Bucha',               'Bucha',             39.1650, -6.7775),
  (7, 'Kimara Suka',         'Kimara Suka',       39.1570, -6.7758),
  (8, 'Kimara Korogwe',      'Kimara Korogwe',    39.1508, -6.7744),
  (9, 'Kimara Mwisho',       'Kimara Mwisho',     39.1370, -6.7700);

-- ---------------------------------------------------------------------------
-- Routes. The westbound line runs in stage order; the eastbound one is the
-- same road reversed, which is exactly what makes "ahead of me" work in both
-- directions without any special-casing.
-- ---------------------------------------------------------------------------
insert into public.routes (id, name, name_sw, direction_label, geom, corridor_m, active)
select
  '11111111-1111-4111-8111-111111111111'::uuid,
  'Morogoro Road, Ubungo to Kimara',
  'Barabara ya Morogoro, Ubungo hadi Kimara',
  'Westbound',
  st_makeline(st_setsrid(st_makepoint(lon, lat), 4326) order by seq)::geography,
  300,
  true
from seed_stages;

insert into public.routes (id, name, name_sw, direction_label, geom, corridor_m, active)
select
  '22222222-2222-4222-8222-222222222222'::uuid,
  'Morogoro Road, Kimara to Ubungo',
  'Barabara ya Morogoro, Kimara hadi Ubungo',
  'Eastbound',
  st_makeline(st_setsrid(st_makepoint(lon, lat), 4326) order by seq desc)::geography,
  300,
  true
from seed_stages;

-- ---------------------------------------------------------------------------
-- Stages on each route. Sequence ascends in the direction of travel, so the
-- same physical stage has seq 2 westbound and seq 7 eastbound.
-- ---------------------------------------------------------------------------
insert into public.stages (route_id, name, name_sw, geom, seq)
select
  '11111111-1111-4111-8111-111111111111'::uuid,
  name, name_sw,
  st_setsrid(st_makepoint(lon, lat), 4326)::geography,
  seq
from seed_stages;

insert into public.stages (route_id, name, name_sw, geom, seq)
select
  '22222222-2222-4222-8222-222222222222'::uuid,
  name, name_sw,
  st_setsrid(st_makepoint(lon, lat), 4326)::geography,
  (select max(seq) from seed_stages) - seq
from seed_stages;

-- ---------------------------------------------------------------------------
-- Price bands.
--
-- Two anchors come from the pitch deck's observed ranges, end to end from
-- Ubungo:
--     Kimara Korogwe   TSh 1,000 - 1,500
--     Kimara Mwisho    TSh 1,500 - 2,000
--
-- Every other pair is INTERPOLATED BY DISTANCE from those anchors and rounded
-- to the nearest 100. These are placeholders that let the app run, not
-- observed prices. Replace them with what drivers actually accept -- the
-- unmatched-expiry log (ARCHITECTURE §7) is the fastest way to find out.
--
-- Bajaj and boda get the same band for now. A boda carries one passenger and
-- prices differently in practice; that needs real data too.
-- ---------------------------------------------------------------------------
insert into public.price_bands
  (route_id, from_stage_id, to_stage_id, vehicle_type, low, high)
select
  f.route_id,
  f.id,
  t.id,
  v.vehicle_type,
  greatest(500, round(
    ((st_distance(f.geom, t.geom) / 1000.0) * 210 / 100.0)::numeric
  ) * 100)::integer,
  greatest(800, round(
    ((st_distance(f.geom, t.geom) / 1000.0) * 315 / 100.0)::numeric
  ) * 100)::integer
from public.stages f
join public.stages t
  on t.route_id = f.route_id and t.seq > f.seq
cross join (values ('bajaj'::public.vehicle_type), ('boda'::public.vehicle_type))
  as v(vehicle_type);

-- Pin the two anchors to their observed values, overriding the interpolation.
update public.price_bands pb
   set low = 1000, high = 1500
  from public.stages f, public.stages t
 where pb.from_stage_id = f.id and pb.to_stage_id = t.id
   and f.name = 'Ubungo Bus Terminal' and t.name = 'Kimara Korogwe';

update public.price_bands pb
   set low = 1500, high = 2000
  from public.stages f, public.stages t
 where pb.from_stage_id = f.id and pb.to_stage_id = t.id
   and f.name = 'Ubungo Bus Terminal' and t.name = 'Kimara Mwisho';

commit;

-- ---------------------------------------------------------------------------
-- What was seeded.
-- ---------------------------------------------------------------------------
select
  (select count(*) from public.routes)      as routes,
  (select count(*) from public.stages)      as stages,
  (select count(*) from public.price_bands) as price_bands,
  (select round((st_length(geom)/1000.0)::numeric, 1) from public.routes
    where direction_label = 'Westbound') as corridor_km;
