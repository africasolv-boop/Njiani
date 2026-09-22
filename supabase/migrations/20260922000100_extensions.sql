-- Extensions.
--
-- postgis  : the corridor matching in 20260922000500_matching.sql is geometry,
--            not proximity. Nothing else in this schema can express "ahead of
--            me along my route".
-- pgcrypto : gen_random_uuid().
-- pg_cron  : expires stale ride requests. See 20260922000700_cron.sql.
--
-- On Supabase these live in the `extensions` schema by convention. Creating
-- them is idempotent, so re-running a migration is safe.

create extension if not exists postgis;
create extension if not exists pgcrypto;
