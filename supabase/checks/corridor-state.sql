-- Is there a road to drive on?
--
-- Run this when the driver app says it cannot find anywhere to head for.
-- Reads only, writes nothing.
--
-- The commonest answer by far is that `seed.sql` was never run. `supabase db
-- push` applies MIGRATIONS; the Ubungo-Kimara corridor is reference data and
-- lives in `seed.sql`, which push does not touch. An empty `routes` table
-- gives a direction picker with a blank "Starting from your location" and no
-- destinations -- which is what it looked like the first time this project
-- ran against a hosted database.

set search_path = public, extensions;

select
  (select count(*) from public.routes where active)      as active_routes,
  (select count(*) from public.stages where active)      as active_stages,
  (select count(*) from public.price_bands)              as price_bands,
  case
    when (select count(*) from public.routes) = 0
      then 'EMPTY -- run supabase/seed.sql in the SQL editor'
    when (select count(*) from public.stages) = 0
      then 'ROUTES BUT NO STAGES -- seed.sql ran only partly'
    else 'ok'
  end                                                    as verdict;

-- Each route, and how much of it is usable.
select
  r.direction_label,
  r.active,
  count(s.id)                                   as stages,
  round(st_length(r.geom)::numeric / 1000, 1)   as km,
  r.corridor_m
from public.routes r
left join public.stages s on s.route_id = r.id and s.active
group by r.id, r.direction_label, r.active, r.geom, r.corridor_m
order by r.direction_label;

-- What the app would say about a point.
--
-- Replace the coordinates with your own to see exactly what the direction
-- picker sees. LONGITUDE FIRST -- POINT(lng lat). Swapping them lands you off
-- the coast of Somalia, which is close enough to look plausible on a map and
-- far enough to match nothing.
--
-- Ubungo Mataa, from the seed, is POINT(39.2073 -6.7872); Kimara Mwisho is
-- POINT(39.1370 -6.7700). Either should report `on_corridor = t`.
select
  coalesce(w.name, '(nowhere within 3 km)') as nearest_stage,
  round(w.metres)                           as metres_away,
  w.on_corridor,
  w.routes_active,
  case
    when w.routes_active = 0 then 'no roads configured -- run seed.sql'
    when not w.on_corridor   then 'off every corridor -- the app offers the stage list'
    else 'on a corridor -- destinations should be listed'
  end                                       as app_would_say
from public.where_am_i('POINT(39.2073 -6.7872)'::geography) w;
