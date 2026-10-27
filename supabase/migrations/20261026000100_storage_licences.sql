-- Driving licence photos. Component C6.
--
-- A licence photo is the most sensitive thing Njiani stores. It carries a
-- name, a date of birth, a licence number and a face, it is collected under
-- the Personal Data Protection Act 2022 (ARCHITECTURE §12), and it exists for
-- exactly one purpose: a person checking that the driver is who they say they
-- are before a passenger gets into their vehicle.
--
-- So: a private bucket, no public URL ever, and a path shape that makes the
-- owner part of the object name. The design states the rule the screen shows
-- the driver -- "Stored in a private bucket. Only the Njiani team can open
-- it." -- and this file is what makes that sentence true.

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- The bucket.
--
-- `public = false` is the whole point: reads require a signed URL, minted
-- per request with an expiry, and only for someone a policy below lets read.
--
-- The size cap and the MIME allow-list are enforced by Storage itself, before
-- a byte is written. A client-side check would be a convenience; this is the
-- limit.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'licences',
  'licences',
  false,
  5 * 1024 * 1024,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update
  set public             = false,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- Policies on storage.objects, scoped to this bucket.
--
-- The path is `<auth.uid()>/licence.<ext>`, so the first folder segment IS the
-- owner. That is what makes "your own object" expressible as a policy at all:
-- `storage.foldername(name)` splits the path, and segment 1 has to match the
-- caller. A flat `licence-<uuid>.jpg` would leave no way to say it.
-- ---------------------------------------------------------------------------

-- Upload your own.
create policy licences_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'licences'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Replace your own. Needed by the rejection flow: the driver retakes the
-- photo and overwrites it, keeping their queue position.
create policy licences_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'licences'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'licences'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Read your own, or anyone's if you are an admin.
--
-- The driver can read their own photo because the sign-up screen shows them
-- what they submitted. An admin reads every photo because that is the job.
-- Nobody else -- no passenger, and no other driver -- has any policy here.
create policy licences_read_own_or_admin on storage.objects
  for select to authenticated
  using (
    bucket_id = 'licences'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_admin()
    )
  );

-- ---------------------------------------------------------------------------
-- NO DELETE POLICY.
--
-- Deliberate. A licence photo is the evidence behind an approval decision, so
-- a driver cannot erase it after the fact, and an admin cannot do it by
-- accident from the app. Deletion is a data-retention job, done with the
-- service role, and belongs with the retention schedule at C17 -- not here.
-- ---------------------------------------------------------------------------

comment on policy licences_read_own_or_admin on storage.objects is
  'C6. Private bucket: the owner and admins only, through signed URLs.';
