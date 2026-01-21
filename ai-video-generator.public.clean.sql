
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;























CREATE FUNCTION public.ensure_free_subscription() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  begin
    insert into public.subscriptions (org_id, plan_code, status)
    values (new.id, 'free_v1', 'active');
  exception
    when unique_violation then
      null;
  end;

  return new;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;


CREATE TABLE public.org_credit_balances (
    org_id uuid NOT NULL,
    plan_code text DEFAULT 'free_v1'::text NOT NULL,
    free_credits_available integer DEFAULT 0 NOT NULL,
    paid_credits_available integer DEFAULT 0 NOT NULL,
    bonus_credits_available integer DEFAULT 0 NOT NULL,
    last_free_refill_at timestamp with time zone,
    next_free_refill_at timestamp with time zone,
    last_paid_reset_at timestamp with time zone,
    next_paid_reset_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);



CREATE FUNCTION public.ensure_org_credit_balance(p_org_id uuid, p_plan_code text) RETURNS public.org_credit_balances
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_plan_code text := COALESCE(p_plan_code, 'free_v1');
  v_balance   public.org_credit_balances%rowtype;
  v_plan_row  public.plan_catalog%rowtype;
  v_now       timestamptz := timezone('utc', now());
BEGIN
  SELECT *
  INTO v_plan_row
  FROM public.plan_catalog
  WHERE plan_code = v_plan_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PLAN_NOT_FOUND';
  END IF;

  INSERT INTO public.org_credit_balances (
    org_id,
    plan_code,
    free_credits_available,
    paid_credits_available,
    bonus_credits_available,
    last_free_refill_at,
    next_free_refill_at,
    last_paid_reset_at,
    next_paid_reset_at,
    updated_at
  )
  VALUES (
    p_org_id,
    v_plan_row.plan_code,
    v_plan_row.free_weekly_credits,
    v_plan_row.included_paid_credits,
    0,
    v_now,
    v_now + INTERVAL '7 days',
    v_now,
    v_now + INTERVAL '30 days',
    v_now
  )
  ON CONFLICT (org_id) DO UPDATE
  SET
    plan_code  = COALESCE(EXCLUDED.plan_code, public.org_credit_balances.plan_code),
    updated_at = EXCLUDED.updated_at
  RETURNING * INTO v_balance;

  RETURN v_balance;
END;
$$;



CREATE FUNCTION public.feature_caps(p_org uuid, p_feature text) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT COALESCE(
    (SELECT caps FROM public.org_entitlements
     WHERE org_id = p_org AND feature_code = p_feature),
    '{}'::jsonb
  );
$$;



CREATE FUNCTION public.generate_org_slug() RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select substring(replace(gen_random_uuid()::text, '-', ''), 1, 16);
$$;



CREATE FUNCTION public.get_user_snapshot(p_org_id uuid, p_profile_id uuid) RETURNS jsonb
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
    'media_generations', coalesce((select jsonb_agg(to_jsonb(vg)) from public.media_generations vg where vg.org_id = p_org_id), '[]'::jsonb),
    'render_jobs', coalesce((select jsonb_agg(to_jsonb(rj)) from public.render_jobs rj where rj.org_id = p_org_id), '[]'::jsonb),
    'media_outputs', coalesce((select jsonb_agg(to_jsonb(vo)) from public.media_outputs vo where vo.org_id = p_org_id), '[]'::jsonb),
    'files', coalesce((select jsonb_agg(to_jsonb(fi)) from public.files fi where fi.org_id = p_org_id and fi.profile_id = p_profile_id), '[]'::jsonb),
    'file_attachments', coalesce((select jsonb_agg(to_jsonb(fa)) from public.file_attachments fa where fa.org_id = p_org_id), '[]'::jsonb)
  );
$$;



CREATE FUNCTION public.handle_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;



CREATE FUNCTION public.has_feature(p_org uuid, p_feature text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT COALESCE(
    (SELECT enabled FROM public.org_entitlements
     WHERE org_id = p_org AND feature_code = p_feature),
    false
  );
$$;


CREATE FUNCTION public.is_org_admin(org uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where m.org_id = org
      and m.profile_id = (select auth.uid())
      and m.status = 'active'
      and m.role in ('owner','admin')
  );
$$;



CREATE FUNCTION public.is_org_member(org uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where m.org_id = org
      and m.profile_id = (select auth.uid())
      and m.status = 'active'
  );
$$;



CREATE FUNCTION public.spend_video_credit(p_org_id uuid, p_profile_id uuid, p_request_id uuid DEFAULT NULL::uuid, p_reason text DEFAULT 'media_generation'::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_plan_code text;
  v_plan      public.plan_catalog%rowtype;
  v_balance   public.org_credit_balances%rowtype;
  v_bucket    text;
  v_now       timestamptz := timezone('utc', now());
BEGIN
  SELECT s.plan_code
  INTO v_plan_code
  FROM public.subscriptions s
  WHERE s.org_id = p_org_id
    AND s.status IN ('active','trialing')
  ORDER BY
    CASE WHEN s.status = 'active' THEN 1 ELSE 0 END DESC,
    s.created_at DESC
  LIMIT 1;

  v_balance := public.ensure_org_credit_balance(
    p_org_id,
    COALESCE(v_plan_code, 'free_v1')
  );

  SELECT *
  INTO v_plan
  FROM public.plan_catalog
  WHERE plan_code = v_balance.plan_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PLAN_NOT_FOUND';
  END IF;

  SELECT *
  INTO v_balance
  FROM public.org_credit_balances
  WHERE org_id = p_org_id
  FOR UPDATE;

  IF v_balance.next_free_refill_at IS NULL OR v_balance.next_free_refill_at <= v_now THEN
    v_balance.free_credits_available := v_plan.free_weekly_credits;
    v_balance.last_free_refill_at    := v_now;
    v_balance.next_free_refill_at    := v_now + INTERVAL '7 days';
  END IF;

  IF v_balance.next_paid_reset_at IS NULL OR v_balance.next_paid_reset_at <= v_now THEN
    v_balance.paid_credits_available := v_plan.included_paid_credits;
    v_balance.last_paid_reset_at     := v_now;
    v_balance.next_paid_reset_at     := v_now + INTERVAL '30 days';
  END IF;

  IF v_balance.free_credits_available > 0 THEN
    v_balance.free_credits_available := v_balance.free_credits_available - 1;
    v_bucket := 'free';
  ELSIF v_balance.paid_credits_available > 0 THEN
    v_balance.paid_credits_available := v_balance.paid_credits_available - 1;
    v_bucket := 'paid';
  ELSIF v_balance.bonus_credits_available > 0 THEN
    v_balance.bonus_credits_available := v_balance.bonus_credits_available - 1;
    v_bucket := 'bonus';
  ELSE
    RAISE EXCEPTION 'INSUFFICIENT_CREDITS';
  END IF;

  UPDATE public.org_credit_balances
  SET
    plan_code               = v_plan.plan_code,
    free_credits_available  = v_balance.free_credits_available,
    paid_credits_available  = v_balance.paid_credits_available,
    bonus_credits_available = v_balance.bonus_credits_available,
    last_free_refill_at     = v_balance.last_free_refill_at,
    next_free_refill_at     = v_balance.next_free_refill_at,
    last_paid_reset_at      = v_balance.last_paid_reset_at,
    next_paid_reset_at      = v_balance.next_paid_reset_at,
    updated_at              = v_now
  WHERE org_id = p_org_id;

  INSERT INTO public.credit_transactions (
    org_id,
    profile_id,
    request_id,
    bucket,
    change,
    reason
  )
  VALUES (
    p_org_id,
    p_profile_id,
    p_request_id,
    v_bucket,
    -1,
    COALESCE(p_reason, 'media_generation')
  )
  ON CONFLICT DO NOTHING;

  RETURN jsonb_build_object(
    'bucket',              v_bucket,
    'free_remaining',      v_balance.free_credits_available,
    'paid_remaining',      v_balance.paid_credits_available,
    'bonus_remaining',     v_balance.bonus_credits_available,
    'next_free_refill_at', v_balance.next_free_refill_at,
    'next_paid_reset_at',  v_balance.next_paid_reset_at
  );

EXCEPTION
  WHEN raise_exception THEN
    IF SQLERRM LIKE '%INSUFFICIENT_CREDITS%' THEN
      RAISE EXCEPTION 'INSUFFICIENT_CREDITS';
    ELSE
      RAISE;
    END IF;
END;
$$;



CREATE FUNCTION public.touch_org_credit_balances() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;



CREATE TABLE public.action_costs (
    plan_code text,
    action_code text NOT NULL,
    unit_type text NOT NULL,
    credits_per_unit numeric(12,4),
    min_units numeric(12,4) DEFAULT 0 NOT NULL,
    max_units numeric(12,4),
    resolution_multiplier numeric(8,4) DEFAULT 1.0,
    model_tier text,
    ai_type text NOT NULL,
    cost_mode text NOT NULL,
    fixed_credits integer,
    tokens_per_credit integer,
    min_credits integer DEFAULT 1 NOT NULL,
    max_credits integer,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    CONSTRAINT action_costs_unit_type_check CHECK ((unit_type = ANY (ARRAY['seconds'::text, 'frames'::text, 'tokens'::text, 'flat'::text]))),
    CONSTRAINT action_costs_cost_mode_check CHECK ((cost_mode = ANY (ARRAY['fixed'::text, 'token'::text]))),
    CONSTRAINT action_costs_cost_mode_valid CHECK ((((cost_mode = 'fixed'::text) AND (fixed_credits IS NOT NULL)) OR ((cost_mode = 'token'::text) AND (tokens_per_credit IS NOT NULL)))),
    CONSTRAINT action_costs_min_max_valid CHECK (((max_credits IS NULL) OR (max_credits >= min_credits)))
);



CREATE TABLE public.addon_catalog (
    addon_code text NOT NULL,
    name text NOT NULL,
    monthly_price_cents integer NOT NULL,
    currency text DEFAULT 'USD'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);



CREATE TABLE public.addon_features (
    addon_code text NOT NULL,
    feature_code text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    caps jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);



CREATE TABLE public.ai_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    profile_id uuid,
    created_by uuid,
    request_kind text DEFAULT 'generate'::text NOT NULL,
    prompt text NOT NULL,
    model text DEFAULT 'gpt-4.1-mini'::text NOT NULL,
    temperature numeric(3,2) DEFAULT 0.80 NOT NULL,
    status text DEFAULT 'queued'::text NOT NULL,
    error jsonb,
    error_code text,
    error_message text,
    response_ms integer,
    latency_ms integer,
    tokens_prompt integer,
    tokens_completion integer,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    completed_at timestamp with time zone,
    action_code text NOT NULL,
    tokens_total integer GENERATED ALWAYS AS ((tokens_prompt + tokens_completion)) STORED,
    provider text DEFAULT 'openai'::text NOT NULL,
    input_assets jsonb,
    output_assets jsonb,
    params jsonb DEFAULT '{}'::jsonb NOT NULL,
    provider_payload jsonb,
    meta jsonb DEFAULT '{}'::jsonb,
    cost_estimation numeric(10,4),
    idempotency_key text,
    request_fingerprint text,
    CONSTRAINT ai_requests_request_kind_check CHECK ((request_kind = ANY (ARRAY['generate'::text, 'extend'::text, 'upscale'::text, 'compile'::text, 'thumbnail'::text, 'subtitle'::text, 'audio'::text, 'other'::text]))),
    CONSTRAINT ai_requests_status_check CHECK ((status = ANY (ARRAY['queued'::text, 'running'::text, 'succeeded'::text, 'failed'::text, 'canceled'::text])))
);



CREATE TABLE public.billing_metrics_daily (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    snapshot_date date NOT NULL,
    window_start timestamp with time zone NOT NULL,
    window_end timestamp with time zone NOT NULL,
    window_hours integer DEFAULT 24 NOT NULL,
    webhook_processed_count integer DEFAULT 0 NOT NULL,
    webhook_failed_count integer DEFAULT 0 NOT NULL,
    webhook_processing_count integer DEFAULT 0 NOT NULL,
    invoice_payment_succeeded_count integer DEFAULT 0 NOT NULL,
    invoice_payment_failed_count integer DEFAULT 0 NOT NULL,
    subscription_refill_count integer DEFAULT 0 NOT NULL,
    credit_hold_count integer DEFAULT 0 NOT NULL,
    credit_release_count integer DEFAULT 0 NOT NULL,
    credit_spend_count integer DEFAULT 0 NOT NULL,
    credit_hold_open_count integer DEFAULT 0 NOT NULL,
    negative_balance_count integer DEFAULT 0 NOT NULL,
    active_subscription_count integer DEFAULT 0 NOT NULL,
    canceled_subscription_count integer DEFAULT 0 NOT NULL,
    subscription_status_counts jsonb DEFAULT '{}'::jsonb NOT NULL,
    plan_code_counts jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);



CREATE TABLE public.credit_holds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    profile_id uuid,
    request_id uuid NOT NULL,
    estimated_credits integer NOT NULL,
    status text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    finalized_at timestamp with time zone,
    CONSTRAINT credit_holds_status_check CHECK ((status = ANY (ARRAY['held'::text, 'finalized'::text, 'released'::text])))
);



CREATE TABLE public.credit_transactions (
    id bigint NOT NULL,
    org_id uuid NOT NULL,
    profile_id uuid,
    request_id uuid,
    bucket text NOT NULL,
    change integer NOT NULL,
    reason text DEFAULT 'media_generation'::text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    stripe_invoice_id text,
    CONSTRAINT credit_transactions_bucket_check CHECK ((bucket = ANY (ARRAY['free'::text, 'paid'::text, 'bonus'::text]))),
    CONSTRAINT credit_txn_negative_request_rule CHECK (((change >= 0) OR ((reason = 'manual_debit'::text) AND (request_id IS NULL)) OR ((reason <> 'manual_debit'::text) AND (request_id IS NOT NULL))))
);



CREATE SEQUENCE public.credit_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.credit_transactions_id_seq OWNED BY public.credit_transactions.id;



CREATE TABLE public.feature_catalog (
    feature_code text NOT NULL,
    description text NOT NULL,
    category text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);



CREATE TABLE public.file_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    file_id uuid NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    role text DEFAULT 'generic'::text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT file_attachments_entity_type_check CHECK ((entity_type = ANY (ARRAY['video_project'::text, 'video_asset'::text, 'media_generation'::text, 'render_job'::text, 'media_output'::text, 'organization'::text, 'profile'::text]))),
    CONSTRAINT file_attachments_role_check CHECK ((role = ANY (ARRAY['cover'::text, 'thumbnail'::text, 'preview'::text, 'input'::text, 'output'::text, 'storyboard'::text, 'audio'::text, 'subtitle'::text, 'attachment'::text, 'avatar'::text, 'other'::text])))
);



CREATE TABLE public.files (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    profile_id uuid,
    bucket text NOT NULL,
    path text NOT NULL,
    file_name text NOT NULL,
    mime_type text,
    size_bytes bigint,
    provider text DEFAULT 'supabase'::text NOT NULL,
    source text DEFAULT 'upload'::text NOT NULL,
    request_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_public boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT files_source_check CHECK ((source = ANY (ARRAY['upload'::text, 'ai_generated'::text, 'external'::text])))
);



CREATE TABLE public.memberships (
    org_id uuid NOT NULL,
    profile_id uuid NOT NULL,
    role text DEFAULT 'member'::text NOT NULL,
    status text DEFAULT 'invited'::text NOT NULL,
    invited_by uuid,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT memberships_role_check CHECK ((role = ANY (ARRAY['owner'::text, 'admin'::text, 'member'::text, 'viewer'::text]))),
    CONSTRAINT memberships_status_check CHECK ((status = ANY (ARRAY['active'::text, 'invited'::text, 'revoked'::text])))
);



CREATE TABLE public.org_addons (
    org_id uuid NOT NULL,
    addon_code text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    started_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    ends_at timestamp with time zone
);



CREATE TABLE public.org_feature_overrides (
    org_id uuid NOT NULL,
    feature_code text NOT NULL,
    enabled boolean,
    caps jsonb DEFAULT '{}'::jsonb NOT NULL,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);



CREATE TABLE public.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    stripe_customer_id text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);



CREATE TABLE public.plan_features (
    plan_code text NOT NULL,
    feature_code text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    caps jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);



CREATE TABLE public.subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    plan_code text NOT NULL,
    seats_limit integer,
    token_limit integer,
    period_starts timestamp with time zone,
    period_ends timestamp with time zone,
    stripe_subscription_id text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    status text DEFAULT 'trialing'::text,
    entity_limits jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT subscriptions_status_check CHECK ((status = ANY (ARRAY['trialing'::text, 'active'::text, 'past_due'::text, 'canceled'::text])))
);



CREATE VIEW public.org_entitlements WITH (security_invoker='true') AS
 WITH active_sub AS (
         SELECT DISTINCT ON (s.org_id) s.org_id,
            s.plan_code
           FROM public.subscriptions s
          WHERE (s.status = ANY (ARRAY['active'::text, 'trialing'::text]))
          ORDER BY s.org_id, s.created_at DESC
        ), sub AS (
         SELECT active_sub.org_id,
            active_sub.plan_code
           FROM active_sub
        UNION ALL
         SELECT o.id AS org_id,
            'free_v1'::text AS plan_code
           FROM public.organizations o
          WHERE (NOT (EXISTS ( SELECT 1
                   FROM active_sub a
                  WHERE (a.org_id = o.id))))
        ), base AS (
         SELECT s.org_id,
            pf.feature_code,
            pf.enabled,
            pf.caps
           FROM (sub s
             JOIN public.plan_features pf ON ((pf.plan_code = s.plan_code)))
        ), addons AS (
         SELECT oa.org_id,
            af.feature_code,
            af.enabled,
            af.caps
           FROM ((public.org_addons oa
             JOIN public.addon_catalog ac ON (((ac.addon_code = oa.addon_code) AND ac.is_active)))
             JOIN public.addon_features af ON ((af.addon_code = oa.addon_code)))
          WHERE ((oa.status = 'active'::text) AND ((oa.ends_at IS NULL) OR (oa.ends_at > timezone('utc'::text, now()))))
        ), over AS (
         SELECT o.org_id,
            o.feature_code,
            o.enabled,
            o.caps
           FROM public.org_feature_overrides o
          WHERE ((o.expires_at IS NULL) OR (o.expires_at > timezone('utc'::text, now())))
        ), feature_union AS (
         SELECT base_1.org_id,
            base_1.feature_code
           FROM base base_1
        UNION
         SELECT addons_1.org_id,
            addons_1.feature_code
           FROM addons addons_1
        UNION
         SELECT over_1.org_id,
            over_1.feature_code
           FROM over over_1
        )
 SELECT fu.org_id,
    fu.feature_code,
        CASE
            WHEN (over.enabled IS NOT NULL) THEN over.enabled
            ELSE (COALESCE(base.enabled, false) OR COALESCE(addons.enabled, false))
        END AS enabled,
    ((COALESCE(base.caps, '{}'::jsonb) || COALESCE(addons.caps, '{}'::jsonb)) || COALESCE(over.caps, '{}'::jsonb)) AS caps
   FROM (((feature_union fu
     LEFT JOIN base ON (((base.org_id = fu.org_id) AND (base.feature_code = fu.feature_code))))
     LEFT JOIN addons ON (((addons.org_id = fu.org_id) AND (addons.feature_code = fu.feature_code))))
     LEFT JOIN over ON (((over.org_id = fu.org_id) AND (over.feature_code = fu.feature_code))));



CREATE TABLE public.plan_catalog (
    plan_code text NOT NULL,
    name text NOT NULL,
    free_weekly_credits integer DEFAULT 0 NOT NULL,
    included_paid_credits integer DEFAULT 0 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    plan_key text NOT NULL,
    plan_version integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    tokens_per_credit integer DEFAULT 1000 NOT NULL,
    is_paid boolean DEFAULT false NOT NULL,
    CONSTRAINT plan_paid_no_free_credits CHECK (((NOT is_paid) OR (free_weekly_credits = 0)))
);



CREATE TABLE public.plan_prices (
    plan_code text NOT NULL,
    billing_cycle text NOT NULL,
    price_cents integer NOT NULL,
    currency text DEFAULT 'USD'::text NOT NULL,
    stripe_price_id text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT plan_prices_billing_cycle_check CHECK ((billing_cycle = ANY (ARRAY['monthly'::text, 'yearly'::text])))
);



CREATE TABLE public.profiles (
    id uuid NOT NULL,
    email text NOT NULL,
    full_name text,
    avatar_url text,
    default_org_id uuid,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);



CREATE TABLE public.stripe_webhook_events (
    event_id text NOT NULL,
    event_type text NOT NULL,
    org_id uuid,
    processed_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'processed'::text NOT NULL,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    queued_at timestamp with time zone,
    next_attempt_at timestamp with time zone,
    last_attempt_at timestamp with time zone,
    attempt_count integer DEFAULT 0 NOT NULL,
    locked_at timestamp with time zone,
    locked_by text
);



CREATE TABLE public.usage_events (
    id bigint NOT NULL,
    request_id uuid,
    org_id uuid NOT NULL,
    profile_id uuid,
    event_type text NOT NULL,
    action_code text DEFAULT 'legacy'::text NOT NULL,
    unit_type text DEFAULT 'tokens'::text NOT NULL,
    units numeric(12,4) DEFAULT 0 NOT NULL,
    credits_charged integer DEFAULT 0 NOT NULL,
    tokens_prompt integer,
    tokens_completion integer,
    cost_usd numeric(10,4),
    duration_ms integer,
    status text,
    generation_id uuid,
    job_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT usage_events_unit_type_check CHECK ((unit_type = ANY (ARRAY['seconds'::text, 'frames'::text, 'tokens'::text, 'flat'::text])))
);



CREATE SEQUENCE public.usage_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



ALTER SEQUENCE public.usage_events_id_seq OWNED BY public.usage_events.id;



CREATE TABLE public.video_projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    name text NOT NULL,
    created_by uuid,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT video_projects_name_length_check CHECK (((char_length(name) >= 1) AND (char_length(name) <= 200)))
);



CREATE TABLE public.video_assets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    project_id uuid,
    file_id uuid,
    asset_type text NOT NULL,
    title text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT video_assets_asset_type_check CHECK ((asset_type = ANY (ARRAY['image'::text, 'video'::text, 'audio'::text, 'subtitle'::text, 'prompt'::text, 'other'::text])))
);



CREATE TABLE public.media_generations (



    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    project_id uuid,
    created_by uuid,
    prompt text NOT NULL,
    negative_prompt text,
    params jsonb DEFAULT '{}'::jsonb NOT NULL,
    provider text NOT NULL,
    model text NOT NULL,
    status text NOT NULL,
    media_type text DEFAULT 'video'::text NOT NULL,
    error_code text,
    error_message text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT media_generations_status_check CHECK ((status = ANY (ARRAY['queued'::text, 'running'::text, 'succeeded'::text, 'failed'::text, 'canceled'::text]))),
    CONSTRAINT media_generations_media_type_check CHECK ((media_type = ANY (ARRAY['video'::text, 'image'::text, 'audio'::text, 'other'::text])))

);



CREATE TABLE public.render_jobs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    generation_id uuid NOT NULL,
    job_type text NOT NULL,
    status text NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 5 NOT NULL,
    next_attempt_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    locked_at timestamp with time zone,
    locked_by text,
    last_error text,
    provider_job_id text,
    idempotency_key text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT render_jobs_attempt_count_check CHECK ((attempt_count >= 0)),
    CONSTRAINT render_jobs_job_type_check CHECK ((job_type = ANY (ARRAY['generate'::text, 'extend'::text, 'upscale'::text, 'compile'::text, 'thumbnail'::text, 'other'::text]))),
    CONSTRAINT render_jobs_max_attempts_check CHECK (((max_attempts >= 1) AND (max_attempts <= 20))),
    CONSTRAINT render_jobs_status_check CHECK ((status = ANY (ARRAY['queued'::text, 'running'::text, 'succeeded'::text, 'failed'::text, 'canceled'::text])))
);



CREATE TABLE public.media_outputs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    generation_id uuid,
    job_id uuid,
    file_id uuid,
    output_type text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT media_outputs_output_type_check CHECK ((output_type = ANY (ARRAY['video'::text, 'image'::text, 'audio'::text, 'zip'::text, 'other'::text])))
);



ALTER TABLE ONLY public.credit_transactions ALTER COLUMN id SET DEFAULT nextval('public.credit_transactions_id_seq'::regclass);



ALTER TABLE ONLY public.usage_events ALTER COLUMN id SET DEFAULT nextval('public.usage_events_id_seq'::regclass);































































ALTER TABLE ONLY public.action_costs
    ADD CONSTRAINT action_costs_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.addon_catalog
    ADD CONSTRAINT addon_catalog_pkey PRIMARY KEY (addon_code);



ALTER TABLE ONLY public.addon_features
    ADD CONSTRAINT addon_features_pkey PRIMARY KEY (addon_code, feature_code);



ALTER TABLE ONLY public.billing_metrics_daily
    ADD CONSTRAINT billing_metrics_daily_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.credit_holds
    ADD CONSTRAINT credit_holds_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT credit_transactions_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.feature_catalog
    ADD CONSTRAINT feature_catalog_pkey PRIMARY KEY (feature_code);



ALTER TABLE ONLY public.file_attachments
    ADD CONSTRAINT file_attachments_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_bucket_path_unique UNIQUE (bucket, path);



ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (org_id, profile_id);



ALTER TABLE ONLY public.org_addons
    ADD CONSTRAINT org_addons_pkey PRIMARY KEY (org_id, addon_code);



ALTER TABLE ONLY public.org_credit_balances
    ADD CONSTRAINT org_credit_balances_pkey PRIMARY KEY (org_id);



ALTER TABLE ONLY public.org_feature_overrides
    ADD CONSTRAINT org_feature_overrides_pkey PRIMARY KEY (org_id, feature_code);



ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_slug_key UNIQUE (slug);



ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_stripe_customer_id_key UNIQUE (stripe_customer_id);



ALTER TABLE ONLY public.plan_catalog
    ADD CONSTRAINT plan_catalog_pkey PRIMARY KEY (plan_code);



ALTER TABLE ONLY public.plan_features
    ADD CONSTRAINT plan_features_pkey PRIMARY KEY (plan_code, feature_code);



ALTER TABLE ONLY public.plan_prices
    ADD CONSTRAINT plan_prices_pkey PRIMARY KEY (plan_code, billing_cycle);



ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_email_key UNIQUE (email);



ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.ai_requests
    ADD CONSTRAINT ai_requests_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.video_projects
    ADD CONSTRAINT video_projects_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.video_assets
    ADD CONSTRAINT video_assets_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.media_generations
    ADD CONSTRAINT media_generations_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.render_jobs
    ADD CONSTRAINT render_jobs_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.media_outputs
    ADD CONSTRAINT media_outputs_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.stripe_webhook_events
    ADD CONSTRAINT stripe_webhook_events_pkey PRIMARY KEY (event_id);



ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);



ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_stripe_subscription_id_key UNIQUE (stripe_subscription_id);



ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_pkey PRIMARY KEY (id);



CREATE UNIQUE INDEX action_costs_pricing_unique ON public.action_costs USING btree (plan_code, action_code, unit_type, COALESCE(model_tier, ''::text));



CREATE INDEX action_costs_plan_code_idx ON public.action_costs USING btree (plan_code);



CREATE INDEX action_costs_action_code_idx ON public.action_costs USING btree (action_code);



CREATE INDEX action_costs_action_code_model_tier_idx ON public.action_costs USING btree (action_code, model_tier);



CREATE INDEX addon_catalog_is_active_idx ON public.addon_catalog USING btree (is_active) WHERE (is_active = true);



CREATE INDEX addon_features_feature_code_idx ON public.addon_features USING btree (feature_code);



CREATE INDEX ai_requests_org_created_at_idx ON public.ai_requests USING btree (org_id, created_at DESC);



CREATE INDEX ai_requests_org_status_created_at_idx ON public.ai_requests USING btree (org_id, status, created_at DESC);



CREATE INDEX ai_requests_provider_model_idx ON public.ai_requests USING btree (provider, model);



CREATE INDEX ai_requests_org_request_fingerprint_idx ON public.ai_requests USING btree (org_id, request_fingerprint) WHERE (request_fingerprint IS NOT NULL);



CREATE UNIQUE INDEX ai_requests_org_idempotency_key_unique ON public.ai_requests USING btree (org_id, idempotency_key);



CREATE INDEX credit_holds_org_status_idx ON public.credit_holds USING btree (org_id, status);



CREATE INDEX credit_holds_profile_id_idx ON public.credit_holds USING btree (profile_id);



CREATE INDEX credit_holds_request_id_idx ON public.credit_holds USING btree (request_id);



CREATE INDEX credit_transactions_org_idx ON public.credit_transactions USING btree (org_id);



CREATE INDEX credit_transactions_profile_id_idx ON public.credit_transactions USING btree (profile_id);



CREATE INDEX credit_transactions_request_idx ON public.credit_transactions USING btree (request_id);



CREATE INDEX file_attachments_file_id_idx ON public.file_attachments USING btree (file_id);



CREATE INDEX file_attachments_org_id_idx ON public.file_attachments USING btree (org_id);



CREATE INDEX files_org_id_idx ON public.files USING btree (org_id);



CREATE INDEX files_profile_id_idx ON public.files USING btree (profile_id);



CREATE INDEX files_request_id_idx ON public.files USING btree (request_id);



CREATE INDEX ix_stripe_webhook_events_created ON public.stripe_webhook_events USING btree (status, created_at) WHERE (status = 'queued'::text);



CREATE INDEX ix_stripe_webhook_events_processing ON public.stripe_webhook_events USING btree (status, locked_at) WHERE (status = 'processing'::text);



CREATE INDEX ix_stripe_webhook_events_queue ON public.stripe_webhook_events USING btree (status, next_attempt_at) WHERE (status = ANY (ARRAY['queued'::text, 'failed'::text]));



CREATE INDEX memberships_profile_id_idx ON public.memberships USING btree (profile_id);



CREATE INDEX org_addons_addon_code_idx ON public.org_addons USING btree (addon_code);



CREATE INDEX org_addons_org_status_ends_idx ON public.org_addons USING btree (org_id, status, ends_at);



CREATE INDEX org_credit_balances_plan_code_idx ON public.org_credit_balances USING btree (plan_code);



CREATE INDEX org_feature_overrides_expires_idx ON public.org_feature_overrides USING btree (expires_at);



CREATE INDEX org_feature_overrides_feature_code_idx ON public.org_feature_overrides USING btree (feature_code);



CREATE UNIQUE INDEX plan_catalog_plan_key_version_key ON public.plan_catalog USING btree (plan_key, plan_version);



CREATE INDEX plan_features_feature_code_idx ON public.plan_features USING btree (feature_code);



CREATE INDEX plan_features_plan_idx ON public.plan_features USING btree (plan_code);



CREATE UNIQUE INDEX plan_prices_stripe_price_id_key ON public.plan_prices USING btree (stripe_price_id) WHERE (stripe_price_id IS NOT NULL);



CREATE INDEX profiles_default_org_id_idx ON public.profiles USING btree (default_org_id);



CREATE INDEX subscriptions_org_created_idx ON public.subscriptions USING btree (org_id, created_at DESC);



CREATE INDEX subscriptions_org_status_created_idx ON public.subscriptions USING btree (org_id, status, created_at DESC);



CREATE INDEX subscriptions_plan_code_idx ON public.subscriptions USING btree (plan_code);



CREATE INDEX usage_events_org_created_at_idx ON public.usage_events USING btree (org_id, created_at DESC);



CREATE INDEX usage_events_org_action_code_created_at_idx ON public.usage_events USING btree (org_id, action_code, created_at DESC);



CREATE INDEX usage_events_request_id_idx ON public.usage_events USING btree (request_id);



CREATE INDEX video_projects_org_created_idx ON public.video_projects USING btree (org_id, created_at DESC);



CREATE UNIQUE INDEX video_projects_org_name_unique ON public.video_projects USING btree (org_id, name) WHERE (deleted_at IS NULL);



CREATE INDEX video_assets_org_created_idx ON public.video_assets USING btree (org_id, created_at DESC);



CREATE INDEX video_assets_org_type_created_idx ON public.video_assets USING btree (org_id, asset_type, created_at DESC);



CREATE INDEX video_assets_project_created_idx ON public.video_assets USING btree (project_id, created_at DESC);



CREATE INDEX video_assets_file_id_idx ON public.video_assets USING btree (file_id);



CREATE INDEX media_generations_org_created_idx ON public.media_generations USING btree (org_id, created_at DESC);



CREATE INDEX media_generations_org_status_created_idx ON public.media_generations USING btree (org_id, status, created_at DESC);



CREATE INDEX media_generations_project_created_idx ON public.media_generations USING btree (project_id, created_at DESC);



CREATE INDEX render_jobs_queue_idx ON public.render_jobs USING btree (status, next_attempt_at) WHERE (status = ANY (ARRAY['queued'::text, 'failed'::text]));



CREATE INDEX render_jobs_org_created_idx ON public.render_jobs USING btree (org_id, created_at DESC);



CREATE INDEX render_jobs_generation_id_idx ON public.render_jobs USING btree (generation_id);



CREATE INDEX render_jobs_locked_at_idx ON public.render_jobs USING btree (locked_at) WHERE (locked_at IS NOT NULL);



CREATE UNIQUE INDEX render_jobs_org_idempotency_key_unique ON public.render_jobs USING btree (org_id, idempotency_key);



CREATE INDEX media_outputs_org_created_idx ON public.media_outputs USING btree (org_id, created_at DESC);



CREATE INDEX media_outputs_generation_created_idx ON public.media_outputs USING btree (generation_id, created_at DESC);



CREATE INDEX media_outputs_job_id_idx ON public.media_outputs USING btree (job_id);



CREATE INDEX media_outputs_file_id_idx ON public.media_outputs USING btree (file_id);



CREATE UNIQUE INDEX ux_billing_metrics_daily_snapshot_date ON public.billing_metrics_daily USING btree (snapshot_date);



CREATE UNIQUE INDEX ux_credit_holds_org_request ON public.credit_holds USING btree (org_id, request_id);



CREATE UNIQUE INDEX ux_credit_txn_spend_per_request ON public.credit_transactions USING btree (org_id, request_id, reason) WHERE ((request_id IS NOT NULL) AND (change < 0));



CREATE UNIQUE INDEX ux_credit_txn_subscription_refill_invoice ON public.credit_transactions USING btree (org_id, stripe_invoice_id, bucket) WHERE ((reason = 'subscription_refill'::text) AND (stripe_invoice_id IS NOT NULL));



CREATE UNIQUE INDEX ux_one_active_sub_per_org ON public.subscriptions USING btree (org_id) WHERE (status = ANY (ARRAY['active'::text, 'trialing'::text]));



CREATE TRIGGER action_costs_updated_at BEFORE UPDATE ON public.action_costs FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();



CREATE TRIGGER video_projects_updated_at BEFORE UPDATE ON public.video_projects FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();



CREATE TRIGGER media_generations_updated_at BEFORE UPDATE ON public.media_generations FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();



CREATE TRIGGER render_jobs_updated_at BEFORE UPDATE ON public.render_jobs FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();



CREATE TRIGGER memberships_updated_at BEFORE UPDATE ON public.memberships FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();



CREATE TRIGGER org_credit_balances_updated_at BEFORE UPDATE ON public.org_credit_balances FOR EACH ROW EXECUTE FUNCTION public.touch_org_credit_balances();



CREATE TRIGGER organizations_ensure_free_subscription AFTER INSERT ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.ensure_free_subscription();



CREATE TRIGGER organizations_updated_at BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();



CREATE TRIGGER plan_prices_updated_at BEFORE UPDATE ON public.plan_prices FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();



CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();



CREATE TRIGGER subscriptions_updated_at BEFORE UPDATE ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();



ALTER TABLE ONLY public.action_costs
    ADD CONSTRAINT action_costs_plan_code_fkey FOREIGN KEY (plan_code) REFERENCES public.plan_catalog(plan_code) ON DELETE CASCADE;



ALTER TABLE ONLY public.addon_features
    ADD CONSTRAINT addon_features_addon_code_fkey FOREIGN KEY (addon_code) REFERENCES public.addon_catalog(addon_code) ON DELETE CASCADE;



ALTER TABLE ONLY public.addon_features
    ADD CONSTRAINT addon_features_feature_code_fkey FOREIGN KEY (feature_code) REFERENCES public.feature_catalog(feature_code) ON DELETE CASCADE;



ALTER TABLE ONLY public.credit_holds
    ADD CONSTRAINT credit_holds_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.credit_holds
    ADD CONSTRAINT credit_holds_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id);



ALTER TABLE ONLY public.credit_holds
    ADD CONSTRAINT credit_holds_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.ai_requests(id) ON DELETE SET NULL;



ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT credit_transactions_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT credit_transactions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id);



ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT credit_transactions_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.ai_requests(id);



ALTER TABLE ONLY public.file_attachments
    ADD CONSTRAINT file_attachments_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.files(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.file_attachments
    ADD CONSTRAINT file_attachments_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);



ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);



ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id);



ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.ai_requests(id);



ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES public.profiles(id);



ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.org_addons
    ADD CONSTRAINT org_addons_addon_code_fkey FOREIGN KEY (addon_code) REFERENCES public.addon_catalog(addon_code) ON DELETE CASCADE;



ALTER TABLE ONLY public.org_addons
    ADD CONSTRAINT org_addons_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.org_credit_balances
    ADD CONSTRAINT org_credit_balances_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.org_credit_balances
    ADD CONSTRAINT org_credit_balances_plan_code_fkey FOREIGN KEY (plan_code) REFERENCES public.plan_catalog(plan_code);



ALTER TABLE ONLY public.org_feature_overrides
    ADD CONSTRAINT org_feature_overrides_feature_code_fkey FOREIGN KEY (feature_code) REFERENCES public.feature_catalog(feature_code) ON DELETE CASCADE;



ALTER TABLE ONLY public.org_feature_overrides
    ADD CONSTRAINT org_feature_overrides_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.plan_features
    ADD CONSTRAINT plan_features_feature_code_fkey FOREIGN KEY (feature_code) REFERENCES public.feature_catalog(feature_code) ON DELETE CASCADE;



ALTER TABLE ONLY public.plan_features
    ADD CONSTRAINT plan_features_plan_code_fkey FOREIGN KEY (plan_code) REFERENCES public.plan_catalog(plan_code) ON DELETE CASCADE;



ALTER TABLE ONLY public.plan_prices
    ADD CONSTRAINT plan_prices_plan_code_fkey FOREIGN KEY (plan_code) REFERENCES public.plan_catalog(plan_code) ON DELETE CASCADE;



ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_default_org_id_fkey FOREIGN KEY (default_org_id) REFERENCES public.organizations(id);





ALTER TABLE ONLY public.ai_requests
    ADD CONSTRAINT ai_requests_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.ai_requests
    ADD CONSTRAINT ai_requests_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id);



ALTER TABLE ONLY public.ai_requests
    ADD CONSTRAINT ai_requests_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);



ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_plan_catalog_plan_code_fkey FOREIGN KEY (plan_code) REFERENCES public.plan_catalog(plan_code);



ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id);



ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.ai_requests(id) ON DELETE SET NULL;



ALTER TABLE ONLY public.video_projects
    ADD CONSTRAINT video_projects_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.video_projects
    ADD CONSTRAINT video_projects_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);



ALTER TABLE ONLY public.video_assets
    ADD CONSTRAINT video_assets_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.video_assets
    ADD CONSTRAINT video_assets_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.video_projects(id) ON DELETE SET NULL;



ALTER TABLE ONLY public.video_assets
    ADD CONSTRAINT video_assets_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.files(id) ON DELETE SET NULL;



ALTER TABLE ONLY public.video_assets
    ADD CONSTRAINT video_assets_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);



ALTER TABLE ONLY public.media_generations
    ADD CONSTRAINT media_generations_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.media_generations
    ADD CONSTRAINT media_generations_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.video_projects(id) ON DELETE SET NULL;



ALTER TABLE ONLY public.media_generations
    ADD CONSTRAINT media_generations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);



ALTER TABLE ONLY public.render_jobs
    ADD CONSTRAINT render_jobs_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.render_jobs
    ADD CONSTRAINT render_jobs_generation_id_fkey FOREIGN KEY (generation_id) REFERENCES public.media_generations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.media_outputs
    ADD CONSTRAINT media_outputs_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.media_outputs
    ADD CONSTRAINT media_outputs_generation_id_fkey FOREIGN KEY (generation_id) REFERENCES public.media_generations(id) ON DELETE CASCADE;



ALTER TABLE ONLY public.media_outputs
    ADD CONSTRAINT media_outputs_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.render_jobs(id) ON DELETE SET NULL;



ALTER TABLE ONLY public.media_outputs
    ADD CONSTRAINT media_outputs_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.files(id) ON DELETE SET NULL;



ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_generation_id_fkey FOREIGN KEY (generation_id) REFERENCES public.media_generations(id) ON DELETE SET NULL;



ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.render_jobs(id) ON DELETE SET NULL;



CREATE POLICY "Admins can update requests" ON public.ai_requests FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY "Admins can view usage" ON public.usage_events FOR SELECT USING (public.is_org_admin(org_id));



CREATE POLICY "Members can insert requests" ON public.ai_requests FOR INSERT WITH CHECK (public.is_org_member(org_id));



CREATE POLICY "Members can view memberships in their org" ON public.memberships FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Members can view subscription" ON public.subscriptions FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Members view credit balances" ON public.org_credit_balances FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Members view credit transactions" ON public.credit_transactions FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Members view their org requests" ON public.ai_requests FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Members can view files" ON public.files FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Members can insert files" ON public.files FOR INSERT WITH CHECK (public.is_org_member(org_id));



CREATE POLICY "Admins can update files" ON public.files FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY "Admins can delete files" ON public.files FOR DELETE USING (public.is_org_admin(org_id));



CREATE POLICY "Members can view file attachments" ON public.file_attachments FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Members can insert file attachments" ON public.file_attachments FOR INSERT WITH CHECK (public.is_org_member(org_id));



CREATE POLICY "Admins can update file attachments" ON public.file_attachments FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY "Admins can delete file attachments" ON public.file_attachments FOR DELETE USING (public.is_org_admin(org_id));



CREATE POLICY "Members can view video projects" ON public.video_projects FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Members can insert video projects" ON public.video_projects FOR INSERT WITH CHECK (public.is_org_member(org_id));



CREATE POLICY "Admins can update video projects" ON public.video_projects FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY "Admins can delete video projects" ON public.video_projects FOR DELETE USING (public.is_org_admin(org_id));



CREATE POLICY "Members can view video assets" ON public.video_assets FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Members can insert video assets" ON public.video_assets FOR INSERT WITH CHECK (public.is_org_member(org_id));



CREATE POLICY "Admins can update video assets" ON public.video_assets FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY "Admins can delete video assets" ON public.video_assets FOR DELETE USING (public.is_org_admin(org_id));



CREATE POLICY "Members can view media generations" ON public.media_generations FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Members can insert media generations" ON public.media_generations FOR INSERT WITH CHECK (public.is_org_member(org_id));



CREATE POLICY "Admins can update media generations" ON public.media_generations FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY "Admins can delete media generations" ON public.media_generations FOR DELETE USING (public.is_org_admin(org_id));



CREATE POLICY "Members can view render jobs" ON public.render_jobs FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Admins can insert render jobs" ON public.render_jobs FOR INSERT WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY "Admins can update render jobs" ON public.render_jobs FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY "Admins can delete render jobs" ON public.render_jobs FOR DELETE USING (public.is_org_admin(org_id));



CREATE POLICY "Members can view media outputs" ON public.media_outputs FOR SELECT USING (public.is_org_member(org_id));



CREATE POLICY "Admins can insert media outputs" ON public.media_outputs FOR INSERT WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY "Admins can update media outputs" ON public.media_outputs FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY "Admins can delete media outputs" ON public.media_outputs FOR DELETE USING (public.is_org_admin(org_id));



CREATE POLICY "Organizations are viewable by members" ON public.organizations FOR SELECT USING (public.is_org_member(id));



CREATE POLICY "Plan catalog readable" ON public.plan_catalog FOR SELECT TO authenticated USING (true);




ALTER TABLE public.action_costs ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.addon_catalog ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.addon_features ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.ai_requests ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.video_projects ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.video_assets ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.media_generations ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.render_jobs ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.media_outputs ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.credit_holds ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.feature_catalog ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.file_attachments ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.files ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;



CREATE POLICY memberships_admin_delete ON public.memberships FOR DELETE USING (public.is_org_admin(org_id));



CREATE POLICY memberships_admin_insert ON public.memberships FOR INSERT WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY memberships_admin_update ON public.memberships FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));



ALTER TABLE public.org_addons ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.org_credit_balances ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.org_feature_overrides ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;



CREATE POLICY organizations_admin_delete ON public.organizations FOR DELETE USING (public.is_org_admin(id));



CREATE POLICY organizations_admin_insert ON public.organizations FOR INSERT WITH CHECK (public.is_org_admin(id));



CREATE POLICY organizations_admin_update ON public.organizations FOR UPDATE USING (public.is_org_admin(id)) WITH CHECK (public.is_org_admin(id));



ALTER TABLE public.plan_catalog ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.plan_features ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.plan_prices ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;





ALTER TABLE public.stripe_webhook_events ENABLE ROW LEVEL SECURITY;



ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;



CREATE POLICY subscriptions_admin_delete ON public.subscriptions FOR DELETE USING (public.is_org_admin(org_id));



CREATE POLICY subscriptions_admin_insert ON public.subscriptions FOR INSERT WITH CHECK (public.is_org_admin(org_id));



CREATE POLICY subscriptions_admin_update ON public.subscriptions FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));



ALTER TABLE public.usage_events ENABLE ROW LEVEL SECURITY;





























