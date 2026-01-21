-- Rename video_* tables to media_* for broader scope
ALTER TABLE public.video_generations RENAME TO media_generations;
ALTER TABLE public.video_outputs RENAME TO media_outputs;

-- Rename constraints and indexes for media_generations
ALTER TABLE public.media_generations RENAME CONSTRAINT video_generations_pkey TO media_generations_pkey;
ALTER TABLE public.media_generations RENAME CONSTRAINT video_generations_status_check TO media_generations_status_check;
ALTER TABLE public.media_generations RENAME CONSTRAINT video_generations_org_id_fkey TO media_generations_org_id_fkey;
ALTER TABLE public.media_generations RENAME CONSTRAINT video_generations_project_id_fkey TO media_generations_project_id_fkey;
ALTER TABLE public.media_generations RENAME CONSTRAINT video_generations_created_by_fkey TO media_generations_created_by_fkey;

ALTER INDEX video_generations_org_created_idx RENAME TO media_generations_org_created_idx;
ALTER INDEX video_generations_org_status_created_idx RENAME TO media_generations_org_status_created_idx;
ALTER INDEX video_generations_project_created_idx RENAME TO media_generations_project_created_idx;

ALTER TRIGGER video_generations_updated_at ON public.media_generations RENAME TO media_generations_updated_at;

-- Rename constraints and indexes for media_outputs
ALTER TABLE public.media_outputs RENAME CONSTRAINT video_outputs_pkey TO media_outputs_pkey;
ALTER TABLE public.media_outputs RENAME CONSTRAINT video_outputs_output_type_check TO media_outputs_output_type_check;
ALTER TABLE public.media_outputs RENAME CONSTRAINT video_outputs_org_id_fkey TO media_outputs_org_id_fkey;
ALTER TABLE public.media_outputs RENAME CONSTRAINT video_outputs_generation_id_fkey TO media_outputs_generation_id_fkey;
ALTER TABLE public.media_outputs RENAME CONSTRAINT video_outputs_job_id_fkey TO media_outputs_job_id_fkey;
ALTER TABLE public.media_outputs RENAME CONSTRAINT video_outputs_file_id_fkey TO media_outputs_file_id_fkey;

ALTER INDEX video_outputs_org_created_idx RENAME TO media_outputs_org_created_idx;
ALTER INDEX video_outputs_generation_created_idx RENAME TO media_outputs_generation_created_idx;
ALTER INDEX video_outputs_job_id_idx RENAME TO media_outputs_job_id_idx;
ALTER INDEX video_outputs_file_id_idx RENAME TO media_outputs_file_id_idx;

-- Add media_type for multi-modality
ALTER TABLE public.media_generations
  ADD COLUMN media_type text NOT NULL DEFAULT 'video';

ALTER TABLE public.media_generations
  ADD CONSTRAINT media_generations_media_type_check
  CHECK (media_type IN ('video','image','audio','other'));

-- Update get_user_snapshot to use media_* tables
CREATE OR REPLACE FUNCTION public.get_user_snapshot(p_org_id uuid, p_profile_id uuid) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select jsonb_build_object(
    'organizations', (select to_jsonb(o) from public.organizations o where o.id = p_org_id),
    'profiles', (select to_jsonb(p) from public.profiles p where p.id = p_profile_id),
    'memberships', coalesce((select jsonb_agg(to_jsonb(m)) from public.memberships m where m.org_id = p_org_id and m.profile_id = p_profile_id), '[]'::jsonb),
    'subscriptions', coalesce((select jsonb_agg(to_jsonb(s)) from public.subscriptions s where s.org_id = p_org_id), '[]'::jsonb),
    'org_credit_balances', (select to_jsonb(b) from public.org_credit_balances b where b.org_id = p_org_id),
    'org_addons', coalesce((select jsonb_agg(to_jsonb(oa)) from public.org_addons oa where oa.org_id = p_org_id), '[]'::jsonb),
    'org_feature_overrides', coalesce((select jsonb_agg(to_jsonb(ofo)) from public.org_feature_overrides ofo where ofo.org_id = p_org_id), '[]'::jsonb),

    'ai_requests', coalesce((select jsonb_agg(to_jsonb(ar)) from public.ai_requests ar where ar.org_id = p_org_id and (ar.profile_id = p_profile_id or ar.created_by = p_profile_id)), '[]'::jsonb),
    'usage_events', coalesce((select jsonb_agg(to_jsonb(ue)) from public.usage_events ue where ue.org_id = p_org_id and ue.profile_id = p_profile_id), '[]'::jsonb),
    'credit_transactions', coalesce((select jsonb_agg(to_jsonb(ct)) from public.credit_transactions ct where ct.org_id = p_org_id and ct.profile_id = p_profile_id), '[]'::jsonb),

    'video_projects', coalesce((select jsonb_agg(to_jsonb(vp)) from public.video_projects vp where vp.org_id = p_org_id), '[]'::jsonb),
    'video_assets', coalesce((select jsonb_agg(to_jsonb(va)) from public.video_assets va where va.org_id = p_org_id), '[]'::jsonb),
    'media_generations', coalesce((select jsonb_agg(to_jsonb(mg)) from public.media_generations mg where mg.org_id = p_org_id), '[]'::jsonb),
    'render_jobs', coalesce((select jsonb_agg(to_jsonb(rj)) from public.render_jobs rj where rj.org_id = p_org_id), '[]'::jsonb),
    'media_outputs', coalesce((select jsonb_agg(to_jsonb(mo)) from public.media_outputs mo where mo.org_id = p_org_id), '[]'::jsonb),
    'files', coalesce((select jsonb_agg(to_jsonb(fi)) from public.files fi where fi.org_id = p_org_id and fi.profile_id = p_profile_id), '[]'::jsonb),
    'file_attachments', coalesce((select jsonb_agg(to_jsonb(fa)) from public.file_attachments fa where fa.org_id = p_org_id), '[]'::jsonb)
  );
$$;

-- Update file_attachments entity_type values and constraint
UPDATE public.file_attachments
SET entity_type = CASE entity_type
  WHEN 'video_generation' THEN 'media_generation'
  WHEN 'video_output' THEN 'media_output'
  ELSE entity_type
END;

ALTER TABLE public.file_attachments
  DROP CONSTRAINT file_attachments_entity_type_check;

ALTER TABLE public.file_attachments
  ADD CONSTRAINT file_attachments_entity_type_check
  CHECK ((entity_type = ANY (ARRAY['video_project'::text, 'video_asset'::text, 'media_generation'::text, 'render_job'::text, 'media_output'::text, 'organization'::text, 'profile'::text])));

-- Rename policies for clarity
ALTER POLICY "Members can view video generations" ON public.media_generations RENAME TO "Members can view media generations";
ALTER POLICY "Members can insert video generations" ON public.media_generations RENAME TO "Members can insert media generations";
ALTER POLICY "Admins can update video generations" ON public.media_generations RENAME TO "Admins can update media generations";
ALTER POLICY "Admins can delete video generations" ON public.media_generations RENAME TO "Admins can delete media generations";

ALTER POLICY "Members can view video outputs" ON public.media_outputs RENAME TO "Members can view media outputs";
ALTER POLICY "Admins can insert video outputs" ON public.media_outputs RENAME TO "Admins can insert media outputs";
ALTER POLICY "Admins can update video outputs" ON public.media_outputs RENAME TO "Admins can update media outputs";
ALTER POLICY "Admins can delete video outputs" ON public.media_outputs RENAME TO "Admins can delete media outputs";
