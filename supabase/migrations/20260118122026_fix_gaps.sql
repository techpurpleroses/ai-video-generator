-- Fix credit_holds request_id nullability to allow ON DELETE SET NULL
ALTER TABLE public.credit_holds
  ALTER COLUMN request_id DROP NOT NULL;

-- Ensure a default free plan exists for ensure_free_subscription
INSERT INTO public.plan_catalog (
  plan_code,
  name,
  free_weekly_credits,
  included_paid_credits,
  notes,
  created_at,
  plan_key,
  plan_version,
  is_active,
  tokens_per_credit,
  is_paid
)
VALUES (
  'free_v1',
  'Free',
  0,
  0,
  'Default free plan',
  timezone('utc', now()),
  'free',
  1,
  true,
  1000,
  false
)
ON CONFLICT (plan_code) DO NOTHING;

-- Add missing FK from profiles to auth.users
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_id_fkey'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_id_fkey
      FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Profiles RLS policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'Users can view themselves'
  ) THEN
    CREATE POLICY "Users can view themselves"
      ON public.profiles
      FOR SELECT
      USING (id = auth.uid());
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'Org members can view teammates'
  ) THEN
    CREATE POLICY "Org members can view teammates"
      ON public.profiles
      FOR SELECT
      USING (
        EXISTS (
          SELECT 1
          FROM public.memberships m
          WHERE m.profile_id = public.profiles.id
            AND public.is_org_member(m.org_id)
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'Users can update their profile'
  ) THEN
    CREATE POLICY "Users can update their profile"
      ON public.profiles
      FOR UPDATE
      USING (id = auth.uid())
      WITH CHECK (id = auth.uid());
  END IF;
END $$;

-- Optional onboarding helper
CREATE OR REPLACE FUNCTION public.bootstrap_personal_workspace() RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_org public.organizations%rowtype;
  v_org_name text;
  v_free_plan_code text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    INSERT INTO public.profiles (id, email, full_name, avatar_url)
    VALUES (
      v_user_id,
      COALESCE(
        (SELECT email FROM auth.users WHERE id = v_user_id LIMIT 1),
        v_user_id::text || '@placeholder.local'
      ),
      COALESCE(
        (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE id = v_user_id LIMIT 1),
        (SELECT raw_user_meta_data->>'name' FROM auth.users WHERE id = v_user_id LIMIT 1)
      ),
      (SELECT raw_user_meta_data->>'avatar_url' FROM auth.users WHERE id = v_user_id LIMIT 1)
    )
    RETURNING * INTO v_profile;
  END IF;

  v_org_name := COALESCE(NULLIF(v_profile.full_name, ''), 'My Workspace') || ' Studio';

  INSERT INTO public.organizations (name, slug)
  VALUES (
    v_org_name,
    public.generate_org_slug()
  )
  RETURNING * INTO v_org;

  INSERT INTO public.memberships (org_id, profile_id, role, status)
  VALUES (v_org.id, v_user_id, 'owner', 'active');

  UPDATE public.profiles
  SET default_org_id = v_org.id
  WHERE id = v_user_id;

  SELECT plan_code
  INTO v_free_plan_code
  FROM public.plan_catalog
  WHERE plan_key = 'free' AND is_active = true
  ORDER BY plan_version DESC
  LIMIT 1;

  IF v_free_plan_code IS NULL THEN
    RAISE EXCEPTION 'FREE_PLAN_NOT_FOUND';
  END IF;

  PERFORM public.ensure_org_credit_balance(v_org.id, v_free_plan_code);

  RETURN v_org.id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.bootstrap_personal_workspace() TO authenticated, service_role;
