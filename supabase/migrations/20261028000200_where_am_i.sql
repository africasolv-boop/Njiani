-- Knowing where the driver is, and saying so honestly. Component C7 fix.
--
-- THE BUG THIS FIXES
--
-- `nearest_stage` had no distance limit. Asked about a point in Amsterdam it
-- returned "Kimara Mwisho", 7,315 km away, and the direction picker printed
-- it under "Starting from your location" as though it were a fact. A stage on
-- another continent is not where you are.
--
-- The second half is worse, because it is silent. When a point is off every
-- corridor, `destinations_ahead` correctly returns nothing -- and the screen
-- said only "No stages ahead of you on this road", which is the same thing it
-- says when the database has no roads in it at all, and the same thing it
-- says at the far end of a route. Three different situations, one message,
-- and no way forward from any of them.
--
-- So the screen now gets told which one it is.

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- nearest_stage, with a radius.
--
-- 3 km: comfortably more than the widest corridor (300 m) plus a bad GPS fix,
-- and comfortably less than "a different part of the city". Beyond it the
-- honest answer is no row, which the caller can then say out loud.
-- ---------------------------------------------------------------------------
-- The DROP is load-bearing: `create or replace` only replaces a function with
-- the SAME signature, so adding the radius would otherwise leave the old
-- one-argument version in place beside it, and `nearest_stage(last_pos)` --
-- which `current_driver_session` calls -- would fail with "is not unique".
drop function if exists public.nearest_stage(geography);

create or replace function public.nearest_stage(
  p_point    geography,
  p_within_m integer default 3000
)
returns table (
  stage_id   uuid,
  route_id   uuid,
  name       text,
  name_sw    text,
  metres     double precision
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select s.id, s.route_id, s.name, s.name_sw, st_distance(s.geom, p_point)
  from public.stages s
  join public.routes r on r.id = s.route_id
  where s.active and r.active
    and st_dwithin(s.geom, p_point, p_within_m)
  order by s.geom <-> p_point
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- Everything the direction picker needs to explain itself.
--
-- One row, one round trip, and enough to tell three situations apart:
--
--   routes_active = 0   the database has no roads. Nothing will ever work
--                       here, and it is a setup problem, not a driver one --
--                       almost always `seed.sql` never having been run, since
--                       `db push` applies migrations and not reference data.
--   on_corridor = false  the driver is somewhere Njiani does not cover yet.
--                       Real, and common: a driver at home, before they drive
--                       to the road.
--   on_corridor = true   they are on a road. If the destination list is still
--                       empty they are at the end of it.
-- ---------------------------------------------------------------------------
create or replace function public.where_am_i(
  p_point    geography,
  p_within_m integer default 3000
)
returns table (
  stage_id      uuid,
  name          text,
  name_sw       text,
  metres        double precision,
  on_corridor   boolean,
  routes_active integer
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    ns.stage_id,
    ns.name,
    ns.name_sw,
    ns.metres,
    exists (
      select 1 from public.routes r
      where r.active and st_dwithin(r.geom, p_point, r.corridor_m)
    ),
    (select count(*)::integer from public.routes where active)
  from (select * from public.nearest_stage(p_point, p_within_m)
        union all
        -- One row always, even when nothing is near: the caller needs the
        -- other two columns regardless, and a zero-row answer would make
        -- "no routes at all" indistinguishable from "no stage nearby".
        select null::uuid, null::uuid, null::text, null::text, null::double precision
        limit 1) ns;
$$;

comment on function public.where_am_i(geography, integer) is
  'C7. Where the driver is, whether they are on a corridor, and whether there '
  'are any corridors to be on.';

revoke execute on function
  public.where_am_i(geography, integer),
  public.nearest_stage(geography, integer)
  from public;
grant execute on function
  public.where_am_i(geography, integer),
  public.nearest_stage(geography, integer)
  to authenticated;
