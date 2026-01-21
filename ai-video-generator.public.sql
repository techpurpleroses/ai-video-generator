--

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

--
-- TOC entry 4942 (class 0 OID 0)
--
-- Name: EXTENSION hypopg; Type: COMMENT; Schema: -; Owner: -
-- Data Pos: 0
--

COMMENT ON EXTENSION hypopg IS 'Hypothetical indexes for PostgreSQL';


--
-- TOC entry 4943 (class 0 OID 0)
--
-- Name: EXTENSION index_advisor; Type: COMMENT; Schema: -; Owner: -
-- Data Pos: 0
--

COMMENT ON EXTENSION index_advisor IS 'Query index advisor';


--
-- TOC entry 4944 (class 0 OID 0)
--
-- Name: EXTENSION pg_graphql; Type: COMMENT; Schema: -; Owner: -
-- Data Pos: 0
--

COMMENT ON EXTENSION pg_graphql IS 'pg_graphql: GraphQL support';


--
-- TOC entry 4945 (class 0 OID 0)
--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
-- Data Pos: 0
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- TOC entry 4946 (class 0 OID 0)
--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
-- Data Pos: 0
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- TOC entry 4947 (class 0 OID 0)
--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
-- Data Pos: 0
--

COMMENT ON EXTENSION supabase_vault IS 'Supabase Vault Extension';


--
-- TOC entry 4948 (class 0 OID 0)
--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
-- Data Pos: 0
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- TOC entry 565 (class 1255 OID 72493)
-- Name: ensure_free_subscription(); Type: FUNCTION; Schema: public; Owner: -
-- Data Pos: 0
--

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
      -- Another concurrent transaction already created an active/trialing subscription for this org.
      -- The partial unique index (ux_one_active_sub_per_org) guarantees safety.
      null;
  end;

  return new;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 401 (class 1259 OID 18014)
-- Name: org_credit_balances; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 475 (class 1255 OID 18072)
--
-- Name: ensure_org_credit_balance(uuid, text); Type: FUNCTION; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 534 (class 1255 OID 72474)
-- Name: feature_caps(uuid, text); Type: FUNCTION; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 462 (class 1255 OID 18078)
-- Name: generate_org_slug(); Type: FUNCTION; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE FUNCTION public.generate_org_slug() RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select substring(replace(gen_random_uuid()::text, '-', ''), 1, 16);
$$;


--
-- TOC entry 577 (class 1255 OID 73825)
-- Name: get_user_snapshot(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 499 (class 1255 OID 17791)
-- Name: handle_updated_at(); Type: FUNCTION; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE FUNCTION public.handle_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;


--
-- TOC entry 580 (class 1255 OID 72473)
-- Name: has_feature(uuid, text); Type: FUNCTION; Schema: public; Owner: -
-- Data Pos: 0
--

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

--
-- TOC entry 467 (class 1255 OID 17858)
-- Name: is_org_admin(uuid); Type: FUNCTION; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 486 (class 1255 OID 17857)
-- Name: is_org_member(uuid); Type: FUNCTION; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 502 (class 1255 OID 18073)
-- Name: spend_video_credit(uuid, uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
-- Data Pos: 0
--

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
  -- Choose plan safely:
  -- 1) active > trialing
  -- 2) latest created_at
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

  -- Lock the balance row to make spend atomic
  SELECT *
  INTO v_balance
  FROM public.org_credit_balances
  WHERE org_id = p_org_id
  FOR UPDATE;

  -- Weekly free refill
  IF v_balance.next_free_refill_at IS NULL OR v_balance.next_free_refill_at <= v_now THEN
    v_balance.free_credits_available := v_plan.free_weekly_credits;
    v_balance.last_free_refill_at    := v_now;
    v_balance.next_free_refill_at    := v_now + INTERVAL '7 days';
  END IF;

  -- Monthly paid reset
  IF v_balance.next_paid_reset_at IS NULL OR v_balance.next_paid_reset_at <= v_now THEN
    v_balance.paid_credits_available := v_plan.included_paid_credits;
    v_balance.last_paid_reset_at     := v_now;
    v_balance.next_paid_reset_at     := v_now + INTERVAL '30 days';
  END IF;

  -- Spend from buckets
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

  -- Persist the new balance
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

  -- Record the spend (idempotent per request)
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


--
-- TOC entry 556 (class 1255 OID 18036)
-- Name: touch_org_credit_balances(); Type: FUNCTION; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE FUNCTION public.touch_org_credit_balances() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;


--
-- TOC entry 434 (class 1259 OID 73744)
-- Name: action_costs; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 429 (class 1259 OID 72436)
-- Name: addon_catalog; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TABLE public.addon_catalog (
    addon_code text NOT NULL,
    name text NOT NULL,
    monthly_price_cents integer NOT NULL,
    currency text DEFAULT 'USD'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- TOC entry 432 (class 1259 OID 72496)
-- Name: addon_features; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TABLE public.addon_features (
    addon_code text NOT NULL,
    feature_code text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    caps jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- TOC entry 396 (class 1259 OID 17880)
-- Name: ai_requests; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 437 (class 1259 OID 86292)
-- Name: billing_metrics_daily; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 435 (class 1259 OID 73764)
-- Name: credit_holds; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 403 (class 1259 OID 18039)
-- Name: credit_transactions; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 402 (class 1259 OID 18038)
--
-- Name: credit_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE SEQUENCE public.credit_transactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4981 (class 0 OID 0)
--
-- Name: credit_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER SEQUENCE public.credit_transactions_id_seq OWNED BY public.credit_transactions.id;


--
-- TOC entry 426 (class 1259 OID 72382)
-- Name: feature_catalog; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TABLE public.feature_catalog (
    feature_code text NOT NULL,
    description text NOT NULL,
    category text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- TOC entry 408 (class 1259 OID 26424)
-- Name: file_attachments; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 407 (class 1259 OID 26372)
-- Name: files; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 394 (class 1259 OID 17831)
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 430 (class 1259 OID 72446)
-- Name: org_addons; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TABLE public.org_addons (
    org_id uuid NOT NULL,
    addon_code text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    started_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    ends_at timestamp with time zone
);


--
-- TOC entry 428 (class 1259 OID 72416)
-- Name: org_feature_overrides; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TABLE public.org_feature_overrides (
    org_id uuid NOT NULL,
    feature_code text NOT NULL,
    enabled boolean,
    caps jsonb DEFAULT '{}'::jsonb NOT NULL,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- TOC entry 392 (class 1259 OID 17792)
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TABLE public.organizations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    stripe_customer_id text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- TOC entry 427 (class 1259 OID 72392)
-- Name: plan_features; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TABLE public.plan_features (
    plan_code text NOT NULL,
    feature_code text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    caps jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- TOC entry 395 (class 1259 OID 17859)
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 431 (class 1259 OID 72468)
--
-- Name: org_entitlements; Type: VIEW; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 400 (class 1259 OID 18002)
-- Name: plan_catalog; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 433 (class 1259 OID 73725)
-- Name: plan_prices; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 393 (class 1259 OID 17809)
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    email text NOT NULL,
    full_name text,
    avatar_url text,
    default_org_id uuid,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- TOC entry 436 (class 1259 OID 79481)
-- Name: stripe_webhook_events; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 399 (class 1259 OID 17938)
-- Name: usage_events; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 398 (class 1259 OID 17937)
--
-- Name: usage_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE SEQUENCE public.usage_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4982 (class 0 OID 0)
--
-- Name: usage_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER SEQUENCE public.usage_events_id_seq OWNED BY public.usage_events.id;


--
-- TOC entry 5001 (class 1259 OID 99001)
-- Name: video_projects; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 5002 (class 1259 OID 99002)
-- Name: video_assets; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 5003 (class 1259 OID 99003)
-- Name: media_generations; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 5004 (class 1259 OID 99004)
-- Name: render_jobs; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 5005 (class 1259 OID 99005)
-- Name: media_outputs; Type: TABLE; Schema: public; Owner: -
-- Data Pos: 0
--

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


--
-- TOC entry 3975 (class 2604 OID 18042)
--
-- Name: credit_transactions id; Type: DEFAULT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.credit_transactions ALTER COLUMN id SET DEFAULT nextval('public.credit_transactions_id_seq'::regclass);


--
-- TOC entry 3960 (class 2604 OID 17941)
--
-- Name: usage_events id; Type: DEFAULT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.usage_events ALTER COLUMN id SET DEFAULT nextval('public.usage_events_id_seq'::regclass);


--
-- TOC entry 4864 (class 0 OID 16525)
--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 349714
--

--
-- TOC entry 4878 (class 0 OID 16929)
--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 349743
--

--
-- TOC entry 4869 (class 0 OID 16727)
--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 353131
--

--
-- TOC entry 4863 (class 0 OID 16518)
--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 353884
--

--
-- TOC entry 4873 (class 0 OID 16816)
--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 353913
--

--
-- TOC entry 4872 (class 0 OID 16804)
--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 354729
--

--
-- TOC entry 4871 (class 0 OID 16791)
--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 354758
--

--
-- TOC entry 4881 (class 0 OID 17041)
--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 354787
--

--
-- TOC entry 4922 (class 0 OID 58467)
--
-- Data for Name: oauth_client_states; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 354816
--

--
-- TOC entry 4880 (class 0 OID 17011)
--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 354845
--

--
-- TOC entry 4882 (class 0 OID 17074)
--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 354874
--

--
-- TOC entry 4879 (class 0 OID 16979)
--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 354903
--

--
-- TOC entry 4862 (class 0 OID 16507)
--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 354932
--

--
-- TOC entry 4876 (class 0 OID 16858)
--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 357463
--

--
-- TOC entry 4877 (class 0 OID 16876)
--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 357492
--

--
-- TOC entry 4865 (class 0 OID 16533)
--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 357521
--

--
-- TOC entry 4870 (class 0 OID 16757)
--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 357926
--

--
-- TOC entry 4875 (class 0 OID 16843)
--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 359005
--

--
-- TOC entry 4874 (class 0 OID 16834)
--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 359034
--

--
-- TOC entry 4860 (class 0 OID 16495)
--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: -
-- Data Pos: 359063
--

--
-- TOC entry 4930 (class 0 OID 73744)
--
-- Data for Name: action_costs; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 360379
--

--
-- TOC entry 4926 (class 0 OID 72436)
--
-- Data for Name: addon_catalog; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 360827
--

--
-- TOC entry 4928 (class 0 OID 72496)
--
-- Data for Name: addon_features; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 360856
--

--
-- TOC entry 4896 (class 0 OID 17880)
--
-- Data for Name: ai_requests; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 360885
--

--
-- TOC entry 4933 (class 0 OID 86292)
--
-- Data for Name: billing_metrics_daily; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 413868
--

--
-- TOC entry 4931 (class 0 OID 73764)
--
-- Data for Name: credit_holds; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 414219
--

-- COPY public.credit_holds (id, org_id, profile_id, request_id, estimated_credits, status, created_at, finalized_at) FROM stdin;
-- \.

--
-- TOC entry 4903 (class 0 OID 18039)
--
-- Data for Name: credit_transactions; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 415517
--

--
-- TOC entry 4923 (class 0 OID 72382)
--
-- Data for Name: feature_catalog; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 426226
--

--
-- TOC entry 4908 (class 0 OID 26424)
--
-- Data for Name: file_attachments; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 426255
--

--
-- TOC entry 4907 (class 0 OID 26372)
--
-- Data for Name: files; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 430046
--

--
-- TOC entry 4894 (class 0 OID 17831)
--
-- Data for Name: memberships; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 552632
--

-- COPY public.memberships (org_id, profile_id, role, status, invited_by, created_at, updated_at) FROM stdin;
-- \.

--
-- TOC entry 4927 (class 0 OID 72446)
--
-- Data for Name: org_addons; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 553643
--

--
-- TOC entry 4901 (class 0 OID 18014)
--
-- Data for Name: org_credit_balances; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 553672
--

--
-- TOC entry 4925 (class 0 OID 72416)
--
-- Data for Name: org_feature_overrides; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 554898
--

--
-- TOC entry 4892 (class 0 OID 17792)
--
-- Data for Name: organizations; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 554927
--

--
-- TOC entry 4900 (class 0 OID 18002)
--
-- Data for Name: plan_catalog; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 556330
--

--
-- TOC entry 4924 (class 0 OID 72392)
--
-- Data for Name: plan_features; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 556535
--

--
-- TOC entry 4929 (class 0 OID 73725)
--
-- Data for Name: plan_prices; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 556564
--

--
-- TOC entry 4893 (class 0 OID 17809)
--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 557397
--

-- COPY public.profiles (id, email, full_name, avatar_url, default_org_id, created_at, updated_at) FROM stdin;
-- 25be76fc-3353-4a67-b2a4-718a60623cd5	pinkeshvaghela19@gmail.com	Pinkesh Vaghela	avatars/25be76fc-3353-4a67-b2a4-718a60623cd5/3447c0ef-7994-4984-9713-c561e7056b2f.jpg	571a4bd9-f643-4466-8f5b-36fac643156e	2025-11-11 06:57:08.913997+00	2025-11-21 13:41:12.752498+00
-- 0f3785f8-d881-41c4-9336-4abfff377442	darshanrana036@gmail.com	Darshan Rana	\N	7450ad50-1594-47dd-b011-9049b9c663bf	2025-12-01 05:57:31.015644+00	2025-12-01 05:57:31.471479+00
-- e424649b-f019-4c2f-ab05-79865fc8d92f	pinkeshpurpleroses@gmail.com	Pinkesh V	avatars/e424649b-f019-4c2f-ab05-79865fc8d92f/b6c46133-9405-4cc7-9afc-e9d003b26f71.jpg	d70dc63b-1ef0-4f4b-bfdb-07b80cdcf145	2025-11-24 07:04:22.320203+00	2025-12-22 09:33:21.855943+00
-- d05ec370-f41c-4898-b95d-d8a1ac82992c	pinkeshvaghela199@gmail.com	Pinkesh	\N	b5902f5a-31bd-436a-b197-4085782aa155	2025-12-26 15:54:09.676195+00	2025-12-26 15:54:12.160223+00
-- 3db14545-3c5f-4ce1-985b-eece5038f254	nuxuwid@gmail.com	Keyur Patel	\N	032c6a30-929c-4ad1-8b48-0ef219b2ce21	2025-12-28 13:21:31.984329+00	2025-12-28 13:21:32.692486+00
-- 9be12bfd-c2af-495f-bb96-bfb4ecb147cf	dream11helpme@gmail.com	Darshil	\N	fa33cb06-f78f-4b35-a0ec-ff5743551d63	2025-12-29 05:29:48.992637+00	2025-12-29 05:29:49.586832+00
-- e62e32e2-0ce3-4640-891c-43985fe9c2c6	techpurpleroses@gmail.com	techpurpleroses	\N	39d946f6-a1ff-4d4f-b232-1a436c4c44be	2025-12-31 10:21:39.302411+00	2025-12-31 10:21:42.175368+00
-- \.

--
-- TOC entry 4932 (class 0 OID 79481)
--
-- Data for Name: stripe_webhook_events; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 613949
--

--
-- TOC entry 4895 (class 0 OID 17859)
--
-- Data for Name: subscriptions; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 648094
--

--
-- TOC entry 4899 (class 0 OID 17938)
--
-- Data for Name: usage_events; Type: TABLE DATA; Schema: public; Owner: -
-- Data Pos: 652549
--

--
-- TOC entry 4883 (class 0 OID 17112)
--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: realtime; Owner: -
-- Data Pos: 664241
--

--
-- TOC entry 4889 (class 0 OID 17289)
--
-- Data for Name: subscription; Type: TABLE DATA; Schema: realtime; Owner: -
-- Data Pos: 664828
--

--
-- TOC entry 4866 (class 0 OID 16546)
--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: -
-- Data Pos: 665170
--

--
-- TOC entry 4887 (class 0 OID 17246)
--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: -
-- Data Pos: 665199
--

--
-- TOC entry 4909 (class 0 OID 30881)
--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: -
-- Data Pos: 665228
--

--
-- TOC entry 4868 (class 0 OID 16588)
--
-- Data for Name: migrations; Type: TABLE DATA; Schema: storage; Owner: -
-- Data Pos: 665257
--

--
-- TOC entry 4867 (class 0 OID 16561)
--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: -
-- Data Pos: 667520
--

--
-- TOC entry 4886 (class 0 OID 17202)
--
-- Data for Name: prefixes; Type: TABLE DATA; Schema: storage; Owner: -
-- Data Pos: 678167
--

--
-- TOC entry 4884 (class 0 OID 17149)
--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: -
-- Data Pos: 680343
--

--
-- TOC entry 4885 (class 0 OID 17163)
--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: -
-- Data Pos: 680372
--

--
-- TOC entry 4910 (class 0 OID 30891)
--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: -
-- Data Pos: 680401
--

--
-- TOC entry 4891 (class 0 OID 17461)
--
-- Data for Name: seed_files; Type: TABLE DATA; Schema: supabase_migrations; Owner: -
-- Data Pos: 684840
--

--
-- TOC entry 3868 (class 0 OID 16658)
--
-- Data for Name: secrets; Type: TABLE DATA; Schema: vault; Owner: -
-- Data Pos: 684869
--

--
-- TOC entry 4987 (class 0 OID 0)
--
-- Name: credit_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
-- Data Pos: 0
--

--
-- TOC entry 4988 (class 0 OID 0)
--
-- Name: usage_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
-- Data Pos: 0
--

--
-- TOC entry 4503 (class 2606 OID 78353)
--
-- Name: action_costs action_costs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.action_costs
    ADD CONSTRAINT action_costs_pkey PRIMARY KEY (id);


--
-- TOC entry 4490 (class 2606 OID 72445)
--
-- Name: addon_catalog addon_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.addon_catalog
    ADD CONSTRAINT addon_catalog_pkey PRIMARY KEY (addon_code);


--
-- TOC entry 4497 (class 2606 OID 72506)
--
-- Name: addon_features addon_features_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.addon_features
    ADD CONSTRAINT addon_features_pkey PRIMARY KEY (addon_code, feature_code);


--
-- TOC entry 4517 (class 2606 OID 86317)
--
-- Name: billing_metrics_daily billing_metrics_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.billing_metrics_daily
    ADD CONSTRAINT billing_metrics_daily_pkey PRIMARY KEY (id);


--
-- TOC entry 4507 (class 2606 OID 73773)
--
-- Name: credit_holds credit_holds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.credit_holds
    ADD CONSTRAINT credit_holds_pkey PRIMARY KEY (id);


--
-- TOC entry 4372 (class 2606 OID 18049)
--
-- Name: credit_transactions credit_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT credit_transactions_pkey PRIMARY KEY (id);


--
-- TOC entry 4479 (class 2606 OID 72389)
--
-- Name: feature_catalog feature_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.feature_catalog
    ADD CONSTRAINT feature_catalog_pkey PRIMARY KEY (feature_code);


--
-- TOC entry 4406 (class 2606 OID 26435)
--
-- Name: file_attachments file_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.file_attachments
    ADD CONSTRAINT file_attachments_pkey PRIMARY KEY (id);


--
-- TOC entry 4397 (class 2606 OID 26388)
--
-- Name: files files_bucket_path_unique; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_bucket_path_unique UNIQUE (bucket, path);


--
-- TOC entry 4400 (class 2606 OID 26386)
--
-- Name: files files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_pkey PRIMARY KEY (id);


--
-- TOC entry 4335 (class 2606 OID 17839)
--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (org_id, profile_id);


--
-- TOC entry 4494 (class 2606 OID 72454)
--
-- Name: org_addons org_addons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.org_addons
    ADD CONSTRAINT org_addons_pkey PRIMARY KEY (org_id, addon_code);


--
-- TOC entry 4368 (class 2606 OID 18025)
--
-- Name: org_credit_balances org_credit_balances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.org_credit_balances
    ADD CONSTRAINT org_credit_balances_pkey PRIMARY KEY (org_id);


--
-- TOC entry 4487 (class 2606 OID 72424)
--
-- Name: org_feature_overrides org_feature_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.org_feature_overrides
    ADD CONSTRAINT org_feature_overrides_pkey PRIMARY KEY (org_id, feature_code);


--
-- TOC entry 4324 (class 2606 OID 17803)
--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- TOC entry 4326 (class 2606 OID 17805)
--
-- Name: organizations organizations_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_slug_key UNIQUE (slug);


--
-- TOC entry 4328 (class 2606 OID 17807)
--
-- Name: organizations organizations_stripe_customer_id_key; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_stripe_customer_id_key UNIQUE (stripe_customer_id);


--
-- TOC entry 4365 (class 2606 OID 18013)
--
-- Name: plan_catalog plan_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.plan_catalog
    ADD CONSTRAINT plan_catalog_pkey PRIMARY KEY (plan_code);


--
-- TOC entry 4482 (class 2606 OID 72402)
--
-- Name: plan_features plan_features_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.plan_features
    ADD CONSTRAINT plan_features_pkey PRIMARY KEY (plan_code, feature_code);


--
-- TOC entry 4499 (class 2606 OID 73736)
--
-- Name: plan_prices plan_prices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.plan_prices
    ADD CONSTRAINT plan_prices_pkey PRIMARY KEY (plan_code, billing_cycle);


--
-- TOC entry 4331 (class 2606 OID 17819)
--
-- Name: profiles profiles_email_key; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_email_key UNIQUE (email);


--
-- TOC entry 4333 (class 2606 OID 17817)
--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- TOC entry 4348 (class 2606 OID 17891)
--
-- Name: ai_requests ai_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.ai_requests
    ADD CONSTRAINT ai_requests_pkey PRIMARY KEY (id);


--
-- TOC entry 5006 (class 2606 OID 99006)
--
-- Name: video_projects video_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.video_projects
    ADD CONSTRAINT video_projects_pkey PRIMARY KEY (id);


--
-- TOC entry 5007 (class 2606 OID 99007)
--
-- Name: video_assets video_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.video_assets
    ADD CONSTRAINT video_assets_pkey PRIMARY KEY (id);


--
-- TOC entry 5008 (class 2606 OID 99008)
--
-- Name: media_generations media_generations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.media_generations
    ADD CONSTRAINT media_generations_pkey PRIMARY KEY (id);


--
-- TOC entry 5009 (class 2606 OID 99009)
--
-- Name: render_jobs render_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.render_jobs
    ADD CONSTRAINT render_jobs_pkey PRIMARY KEY (id);


--
-- TOC entry 5010 (class 2606 OID 99010)
--
-- Name: media_outputs media_outputs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.media_outputs
    ADD CONSTRAINT media_outputs_pkey PRIMARY KEY (id);


--
-- TOC entry 4515 (class 2606 OID 79489)
--
-- Name: stripe_webhook_events stripe_webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.stripe_webhook_events
    ADD CONSTRAINT stripe_webhook_events_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4340 (class 2606 OID 17870)
--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- TOC entry 4343 (class 2606 OID 17872)
--
-- Name: subscriptions subscriptions_stripe_subscription_id_key; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_stripe_subscription_id_key UNIQUE (stripe_subscription_id);


--
-- TOC entry 4361 (class 2606 OID 17947)
--
-- Name: usage_events usage_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_pkey PRIMARY KEY (id);


--
-- TOC entry 4501 (class 1259 OID 73758)
--
-- Name: action_costs_pricing_unique; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE UNIQUE INDEX action_costs_pricing_unique ON public.action_costs USING btree (plan_code, action_code, unit_type, COALESCE(model_tier, ''::text));


--
-- TOC entry 4504 (class 1259 OID 73759)
--
-- Name: action_costs_plan_code_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX action_costs_plan_code_idx ON public.action_costs USING btree (plan_code);


--
-- TOC entry 5011 (class 1259 OID 99011)
--
-- Name: action_costs_action_code_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX action_costs_action_code_idx ON public.action_costs USING btree (action_code);


--
-- TOC entry 5012 (class 1259 OID 99012)
--
-- Name: action_costs_action_code_model_tier_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX action_costs_action_code_model_tier_idx ON public.action_costs USING btree (action_code, model_tier);


--
-- TOC entry 4488 (class 1259 OID 78363)
--
-- Name: addon_catalog_is_active_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX addon_catalog_is_active_idx ON public.addon_catalog USING btree (is_active) WHERE (is_active = true);


--
-- TOC entry 4495 (class 1259 OID 78318)
--
-- Name: addon_features_feature_code_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX addon_features_feature_code_idx ON public.addon_features USING btree (feature_code);


--
-- TOC entry 4345 (class 1259 OID 78365)
--
-- Name: ai_requests_org_created_at_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX ai_requests_org_created_at_idx ON public.ai_requests USING btree (org_id, created_at DESC);


--
-- TOC entry 5013 (class 1259 OID 99013)
--
-- Name: ai_requests_org_status_created_at_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX ai_requests_org_status_created_at_idx ON public.ai_requests USING btree (org_id, status, created_at DESC);


--
-- TOC entry 5014 (class 1259 OID 99014)
--
-- Name: ai_requests_provider_model_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX ai_requests_provider_model_idx ON public.ai_requests USING btree (provider, model);


--
-- TOC entry 5014 (class 1259 OID 99090)
--
-- Name: ai_requests_org_request_fingerprint_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX ai_requests_org_request_fingerprint_idx ON public.ai_requests USING btree (org_id, request_fingerprint) WHERE (request_fingerprint IS NOT NULL);


--
-- TOC entry 5015 (class 1259 OID 99015)
--
-- Name: ai_requests_org_idempotency_key_unique; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE UNIQUE INDEX ai_requests_org_idempotency_key_unique ON public.ai_requests USING btree (org_id, idempotency_key);


--
-- TOC entry 4505 (class 1259 OID 73789)
--
-- Name: credit_holds_org_status_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX credit_holds_org_status_idx ON public.credit_holds USING btree (org_id, status);


--
-- TOC entry 4508 (class 1259 OID 78319)
--
-- Name: credit_holds_profile_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX credit_holds_profile_id_idx ON public.credit_holds USING btree (profile_id);


--
-- TOC entry 4509 (class 1259 OID 78320)
--
-- Name: credit_holds_request_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX credit_holds_request_id_idx ON public.credit_holds USING btree (request_id);


--
-- TOC entry 4370 (class 1259 OID 18065)
--
-- Name: credit_transactions_org_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX credit_transactions_org_idx ON public.credit_transactions USING btree (org_id);


--
-- TOC entry 4373 (class 1259 OID 78321)
--
-- Name: credit_transactions_profile_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX credit_transactions_profile_id_idx ON public.credit_transactions USING btree (profile_id);


--
-- TOC entry 4374 (class 1259 OID 18066)
--
-- Name: credit_transactions_request_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX credit_transactions_request_idx ON public.credit_transactions USING btree (request_id);


--
-- TOC entry 4403 (class 1259 OID 78324)
--
-- Name: file_attachments_file_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX file_attachments_file_id_idx ON public.file_attachments USING btree (file_id);


--
-- TOC entry 4404 (class 1259 OID 78323)
--
-- Name: file_attachments_org_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX file_attachments_org_id_idx ON public.file_attachments USING btree (org_id);


--
-- TOC entry 4398 (class 1259 OID 78325)
--
-- Name: files_org_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX files_org_id_idx ON public.files USING btree (org_id);


--
-- TOC entry 4401 (class 1259 OID 78326)
--
-- Name: files_profile_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX files_profile_id_idx ON public.files USING btree (profile_id);


--
-- TOC entry 4402 (class 1259 OID 78327)
--
-- Name: files_request_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX files_request_id_idx ON public.files USING btree (request_id);


--
-- TOC entry 4511 (class 1259 OID 86337)
--
-- Name: ix_stripe_webhook_events_created; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX ix_stripe_webhook_events_created ON public.stripe_webhook_events USING btree (status, created_at) WHERE (status = 'queued'::text);


--
-- TOC entry 4512 (class 1259 OID 86336)
--
-- Name: ix_stripe_webhook_events_processing; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX ix_stripe_webhook_events_processing ON public.stripe_webhook_events USING btree (status, locked_at) WHERE (status = 'processing'::text);


--
-- TOC entry 4513 (class 1259 OID 86335)
--
-- Name: ix_stripe_webhook_events_queue; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX ix_stripe_webhook_events_queue ON public.stripe_webhook_events USING btree (status, next_attempt_at) WHERE (status = ANY (ARRAY['queued'::text, 'failed'::text]));


--
-- TOC entry 4336 (class 1259 OID 17855)
--
-- Name: memberships_profile_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX memberships_profile_id_idx ON public.memberships USING btree (profile_id);


--
-- TOC entry 4491 (class 1259 OID 78335)
--
-- Name: org_addons_addon_code_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX org_addons_addon_code_idx ON public.org_addons USING btree (addon_code);


--
-- TOC entry 4492 (class 1259 OID 78362)
--
-- Name: org_addons_org_status_ends_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX org_addons_org_status_ends_idx ON public.org_addons USING btree (org_id, status, ends_at);


--
-- TOC entry 4369 (class 1259 OID 78336)
--
-- Name: org_credit_balances_plan_code_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX org_credit_balances_plan_code_idx ON public.org_credit_balances USING btree (plan_code);


--
-- TOC entry 4484 (class 1259 OID 72435)
--
-- Name: org_feature_overrides_expires_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX org_feature_overrides_expires_idx ON public.org_feature_overrides USING btree (expires_at);


--
-- TOC entry 4485 (class 1259 OID 78337)
--
-- Name: org_feature_overrides_feature_code_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX org_feature_overrides_feature_code_idx ON public.org_feature_overrides USING btree (feature_code);


--
-- TOC entry 4366 (class 1259 OID 72518)
--
-- Name: plan_catalog_plan_key_version_key; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE UNIQUE INDEX plan_catalog_plan_key_version_key ON public.plan_catalog USING btree (plan_key, plan_version);


--
-- TOC entry 4480 (class 1259 OID 78338)
--
-- Name: plan_features_feature_code_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX plan_features_feature_code_idx ON public.plan_features USING btree (feature_code);


--
-- TOC entry 4483 (class 1259 OID 72413)
--
-- Name: plan_features_plan_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX plan_features_plan_idx ON public.plan_features USING btree (plan_code);


--
-- TOC entry 4500 (class 1259 OID 73742)
--
-- Name: plan_prices_stripe_price_id_key; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE UNIQUE INDEX plan_prices_stripe_price_id_key ON public.plan_prices USING btree (stripe_price_id) WHERE (stripe_price_id IS NOT NULL);


--
-- TOC entry 4329 (class 1259 OID 78339)
--
-- Name: profiles_default_org_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX profiles_default_org_id_idx ON public.profiles USING btree (default_org_id);


--
-- TOC entry 4337 (class 1259 OID 67833)
--
-- Name: subscriptions_org_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX subscriptions_org_created_idx ON public.subscriptions USING btree (org_id, created_at DESC);


--
-- TOC entry 4338 (class 1259 OID 72480)
--
-- Name: subscriptions_org_status_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX subscriptions_org_status_created_idx ON public.subscriptions USING btree (org_id, status, created_at DESC);


--
-- TOC entry 4341 (class 1259 OID 78342)
--
-- Name: subscriptions_plan_code_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX subscriptions_plan_code_idx ON public.subscriptions USING btree (plan_code);


--
-- TOC entry 4359 (class 1259 OID 17963)
--
-- Name: usage_events_org_created_at_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX usage_events_org_created_at_idx ON public.usage_events USING btree (org_id, created_at DESC);


--
-- TOC entry 5016 (class 1259 OID 99016)
--
-- Name: usage_events_org_action_code_created_at_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX usage_events_org_action_code_created_at_idx ON public.usage_events USING btree (org_id, action_code, created_at DESC);


--
-- TOC entry 4363 (class 1259 OID 17964)
--
-- Name: usage_events_request_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX usage_events_request_id_idx ON public.usage_events USING btree (request_id);


--
-- TOC entry 5017 (class 1259 OID 99017)
--
-- Name: video_projects_org_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX video_projects_org_created_idx ON public.video_projects USING btree (org_id, created_at DESC);


--
-- TOC entry 5018 (class 1259 OID 99018)
--
-- Name: video_projects_org_name_unique; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE UNIQUE INDEX video_projects_org_name_unique ON public.video_projects USING btree (org_id, name) WHERE (deleted_at IS NULL);


--
-- TOC entry 5019 (class 1259 OID 99019)
--
-- Name: video_assets_org_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX video_assets_org_created_idx ON public.video_assets USING btree (org_id, created_at DESC);


--
-- TOC entry 5020 (class 1259 OID 99020)
--
-- Name: video_assets_org_type_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX video_assets_org_type_created_idx ON public.video_assets USING btree (org_id, asset_type, created_at DESC);


--
-- TOC entry 5021 (class 1259 OID 99021)
--
-- Name: video_assets_project_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX video_assets_project_created_idx ON public.video_assets USING btree (project_id, created_at DESC);


--
-- TOC entry 5022 (class 1259 OID 99022)
--
-- Name: video_assets_file_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX video_assets_file_id_idx ON public.video_assets USING btree (file_id);


--
-- TOC entry 5023 (class 1259 OID 99023)
--
-- Name: media_generations_org_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX media_generations_org_created_idx ON public.media_generations USING btree (org_id, created_at DESC);


--
-- TOC entry 5024 (class 1259 OID 99024)
--
-- Name: media_generations_org_status_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX media_generations_org_status_created_idx ON public.media_generations USING btree (org_id, status, created_at DESC);


--
-- TOC entry 5025 (class 1259 OID 99025)
--
-- Name: media_generations_project_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX media_generations_project_created_idx ON public.media_generations USING btree (project_id, created_at DESC);


--
-- TOC entry 5026 (class 1259 OID 99026)
--
-- Name: render_jobs_queue_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX render_jobs_queue_idx ON public.render_jobs USING btree (status, next_attempt_at) WHERE (status = ANY (ARRAY['queued'::text, 'failed'::text]));


--
-- TOC entry 5027 (class 1259 OID 99027)
--
-- Name: render_jobs_org_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX render_jobs_org_created_idx ON public.render_jobs USING btree (org_id, created_at DESC);


--
-- TOC entry 5028 (class 1259 OID 99028)
--
-- Name: render_jobs_generation_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX render_jobs_generation_id_idx ON public.render_jobs USING btree (generation_id);


--
-- TOC entry 5029 (class 1259 OID 99029)
--
-- Name: render_jobs_locked_at_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX render_jobs_locked_at_idx ON public.render_jobs USING btree (locked_at) WHERE (locked_at IS NOT NULL);


--
-- TOC entry 5030 (class 1259 OID 99030)
--
-- Name: render_jobs_org_idempotency_key_unique; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE UNIQUE INDEX render_jobs_org_idempotency_key_unique ON public.render_jobs USING btree (org_id, idempotency_key);


--
-- TOC entry 5031 (class 1259 OID 99031)
--
-- Name: media_outputs_org_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX media_outputs_org_created_idx ON public.media_outputs USING btree (org_id, created_at DESC);


--
-- TOC entry 5032 (class 1259 OID 99032)
--
-- Name: media_outputs_generation_created_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX media_outputs_generation_created_idx ON public.media_outputs USING btree (generation_id, created_at DESC);


--
-- TOC entry 5033 (class 1259 OID 99033)
--
-- Name: media_outputs_job_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX media_outputs_job_id_idx ON public.media_outputs USING btree (job_id);


--
-- TOC entry 5034 (class 1259 OID 99034)
--
-- Name: media_outputs_file_id_idx; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE INDEX media_outputs_file_id_idx ON public.media_outputs USING btree (file_id);


--
-- TOC entry 4518 (class 1259 OID 86320)
--
-- Name: ux_billing_metrics_daily_snapshot_date; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE UNIQUE INDEX ux_billing_metrics_daily_snapshot_date ON public.billing_metrics_daily USING btree (snapshot_date);


--
-- TOC entry 4510 (class 1259 OID 79480)
--
-- Name: ux_credit_holds_org_request; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE UNIQUE INDEX ux_credit_holds_org_request ON public.credit_holds USING btree (org_id, request_id);


--
-- TOC entry 4375 (class 1259 OID 78364)
--
-- Name: ux_credit_txn_spend_per_request; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE UNIQUE INDEX ux_credit_txn_spend_per_request ON public.credit_transactions USING btree (org_id, request_id, reason) WHERE ((request_id IS NOT NULL) AND (change < 0));


--
-- TOC entry 4376 (class 1259 OID 85180)
--
-- Name: ux_credit_txn_subscription_refill_invoice; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE UNIQUE INDEX ux_credit_txn_subscription_refill_invoice ON public.credit_transactions USING btree (org_id, stripe_invoice_id, bucket) WHERE ((reason = 'subscription_refill'::text) AND (stripe_invoice_id IS NOT NULL));


--
-- TOC entry 4344 (class 1259 OID 78369)
--
-- Name: ux_one_active_sub_per_org; Type: INDEX; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE UNIQUE INDEX ux_one_active_sub_per_org ON public.subscriptions USING btree (org_id) WHERE (status = ANY (ARRAY['active'::text, 'trialing'::text]));


--
-- TOC entry 4617 (class 2620 OID 73762)
--
-- Name: action_costs action_costs_updated_at; Type: TRIGGER; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TRIGGER action_costs_updated_at BEFORE UPDATE ON public.action_costs FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


--
-- TOC entry 5037 (class 2620 OID 99057)
--
-- Name: video_projects video_projects_updated_at; Type: TRIGGER; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TRIGGER video_projects_updated_at BEFORE UPDATE ON public.video_projects FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


--
-- TOC entry 5038 (class 2620 OID 99058)
--
-- Name: media_generations media_generations_updated_at; Type: TRIGGER; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TRIGGER media_generations_updated_at BEFORE UPDATE ON public.media_generations FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


--
-- TOC entry 5039 (class 2620 OID 99059)
--
-- Name: render_jobs render_jobs_updated_at; Type: TRIGGER; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TRIGGER render_jobs_updated_at BEFORE UPDATE ON public.render_jobs FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


--
-- TOC entry 4612 (class 2620 OID 17856)
--
-- Name: memberships memberships_updated_at; Type: TRIGGER; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TRIGGER memberships_updated_at BEFORE UPDATE ON public.memberships FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


--
-- TOC entry 4615 (class 2620 OID 18037)
--
-- Name: org_credit_balances org_credit_balances_updated_at; Type: TRIGGER; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TRIGGER org_credit_balances_updated_at BEFORE UPDATE ON public.org_credit_balances FOR EACH ROW EXECUTE FUNCTION public.touch_org_credit_balances();


--
-- TOC entry 4609 (class 2620 OID 72494)
--
-- Name: organizations organizations_ensure_free_subscription; Type: TRIGGER; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TRIGGER organizations_ensure_free_subscription AFTER INSERT ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.ensure_free_subscription();


--
-- TOC entry 4610 (class 2620 OID 17808)
--
-- Name: organizations organizations_updated_at; Type: TRIGGER; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TRIGGER organizations_updated_at BEFORE UPDATE ON public.organizations FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


--
-- TOC entry 4616 (class 2620 OID 73743)
--
-- Name: plan_prices plan_prices_updated_at; Type: TRIGGER; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TRIGGER plan_prices_updated_at BEFORE UPDATE ON public.plan_prices FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


--
-- TOC entry 4611 (class 2620 OID 17830)
--
-- Name: profiles profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


--
-- TOC entry 4613 (class 2620 OID 17879)
--
-- Name: subscriptions subscriptions_updated_at; Type: TRIGGER; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE TRIGGER subscriptions_updated_at BEFORE UPDATE ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


--
-- TOC entry 4597 (class 2606 OID 73753)
--
-- Name: action_costs action_costs_plan_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.action_costs
    ADD CONSTRAINT action_costs_plan_code_fkey FOREIGN KEY (plan_code) REFERENCES public.plan_catalog(plan_code) ON DELETE CASCADE;


--
-- TOC entry 4594 (class 2606 OID 72507)
--
-- Name: addon_features addon_features_addon_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.addon_features
    ADD CONSTRAINT addon_features_addon_code_fkey FOREIGN KEY (addon_code) REFERENCES public.addon_catalog(addon_code) ON DELETE CASCADE;


--
-- TOC entry 4595 (class 2606 OID 72512)
--
-- Name: addon_features addon_features_feature_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.addon_features
    ADD CONSTRAINT addon_features_feature_code_fkey FOREIGN KEY (feature_code) REFERENCES public.feature_catalog(feature_code) ON DELETE CASCADE;


--
-- TOC entry 4598 (class 2606 OID 73774)
--
-- Name: credit_holds credit_holds_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.credit_holds
    ADD CONSTRAINT credit_holds_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 4599 (class 2606 OID 73779)
--
-- Name: credit_holds credit_holds_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.credit_holds
    ADD CONSTRAINT credit_holds_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id);


--
-- TOC entry 4600 (class 2606 OID 73784)
--
-- Name: credit_holds credit_holds_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.credit_holds
    ADD CONSTRAINT credit_holds_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.ai_requests(id) ON DELETE SET NULL;


--
-- TOC entry 4558 (class 2606 OID 18050)
--
-- Name: credit_transactions credit_transactions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT credit_transactions_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 4559 (class 2606 OID 18055)
--
-- Name: credit_transactions credit_transactions_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT credit_transactions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id);


--
-- TOC entry 4560 (class 2606 OID 18060)
--
-- Name: credit_transactions credit_transactions_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.credit_transactions
    ADD CONSTRAINT credit_transactions_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.ai_requests(id);


--
-- TOC entry 4569 (class 2606 OID 26441)
--
-- Name: file_attachments file_attachments_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.file_attachments
    ADD CONSTRAINT file_attachments_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.files(id) ON DELETE CASCADE;


--
-- TOC entry 4570 (class 2606 OID 26436)
--
-- Name: file_attachments file_attachments_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.file_attachments
    ADD CONSTRAINT file_attachments_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);


--
-- TOC entry 4566 (class 2606 OID 26394)
--
-- Name: files files_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id);


--
-- TOC entry 4567 (class 2606 OID 26399)
--
-- Name: files files_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id);


--
-- TOC entry 4568 (class 2606 OID 26389)
--
-- Name: files files_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.ai_requests(id);


--
-- TOC entry 4542 (class 2606 OID 17850)
--
-- Name: memberships memberships_invited_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES public.profiles(id);


--
-- TOC entry 4543 (class 2606 OID 17840)
--
-- Name: memberships memberships_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 4544 (class 2606 OID 17845)
--
-- Name: memberships memberships_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- TOC entry 4592 (class 2606 OID 72460)
--
-- Name: org_addons org_addons_addon_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.org_addons
    ADD CONSTRAINT org_addons_addon_code_fkey FOREIGN KEY (addon_code) REFERENCES public.addon_catalog(addon_code) ON DELETE CASCADE;


--
-- TOC entry 4593 (class 2606 OID 72455)
--
-- Name: org_addons org_addons_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.org_addons
    ADD CONSTRAINT org_addons_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 4556 (class 2606 OID 18026)
--
-- Name: org_credit_balances org_credit_balances_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.org_credit_balances
    ADD CONSTRAINT org_credit_balances_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 4557 (class 2606 OID 18031)
--
-- Name: org_credit_balances org_credit_balances_plan_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.org_credit_balances
    ADD CONSTRAINT org_credit_balances_plan_code_fkey FOREIGN KEY (plan_code) REFERENCES public.plan_catalog(plan_code);


--
-- TOC entry 4590 (class 2606 OID 72430)
--
-- Name: org_feature_overrides org_feature_overrides_feature_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.org_feature_overrides
    ADD CONSTRAINT org_feature_overrides_feature_code_fkey FOREIGN KEY (feature_code) REFERENCES public.feature_catalog(feature_code) ON DELETE CASCADE;


--
-- TOC entry 4591 (class 2606 OID 72425)
--
-- Name: org_feature_overrides org_feature_overrides_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.org_feature_overrides
    ADD CONSTRAINT org_feature_overrides_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 4588 (class 2606 OID 72408)
--
-- Name: plan_features plan_features_feature_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.plan_features
    ADD CONSTRAINT plan_features_feature_code_fkey FOREIGN KEY (feature_code) REFERENCES public.feature_catalog(feature_code) ON DELETE CASCADE;


--
-- TOC entry 4589 (class 2606 OID 72403)
--
-- Name: plan_features plan_features_plan_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.plan_features
    ADD CONSTRAINT plan_features_plan_code_fkey FOREIGN KEY (plan_code) REFERENCES public.plan_catalog(plan_code) ON DELETE CASCADE;


--
-- TOC entry 4596 (class 2606 OID 73737)
--
-- Name: plan_prices plan_prices_plan_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.plan_prices
    ADD CONSTRAINT plan_prices_plan_code_fkey FOREIGN KEY (plan_code) REFERENCES public.plan_catalog(plan_code) ON DELETE CASCADE;


--
-- TOC entry 4540 (class 2606 OID 17825)
--
-- Name: profiles profiles_default_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_default_org_id_fkey FOREIGN KEY (default_org_id) REFERENCES public.organizations(id);


--
-- TOC entry 4541 (class 2606 OID 17820)
--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

-- ALTER TABLE ONLY public.profiles
--    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

--
-- TOC entry 4547 (class 2606 OID 17892)
--
-- Name: ai_requests ai_requests_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.ai_requests
    ADD CONSTRAINT ai_requests_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 4548 (class 2606 OID 17897)
--
-- Name: ai_requests ai_requests_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.ai_requests
    ADD CONSTRAINT ai_requests_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id);


--
-- TOC entry 5019 (class 2606 OID 99039)
--
-- Name: ai_requests ai_requests_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.ai_requests
    ADD CONSTRAINT ai_requests_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- TOC entry 4545 (class 2606 OID 17873)
--
-- Name: subscriptions subscriptions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 4546 (class 2606 OID 18067)
--
-- Name: subscriptions subscriptions_plan_catalog_plan_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_plan_catalog_plan_code_fkey FOREIGN KEY (plan_code) REFERENCES public.plan_catalog(plan_code);


--
-- TOC entry 4553 (class 2606 OID 17953)
--
-- Name: usage_events usage_events_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 4554 (class 2606 OID 17958)
--
-- Name: usage_events usage_events_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id);


--
-- TOC entry 4555 (class 2606 OID 17948)
--
-- Name: usage_events usage_events_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.ai_requests(id) ON DELETE SET NULL;


--
-- TOC entry 5020 (class 2606 OID 99040)
--
-- Name: video_projects video_projects_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.video_projects
    ADD CONSTRAINT video_projects_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 5021 (class 2606 OID 99041)
--
-- Name: video_projects video_projects_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.video_projects
    ADD CONSTRAINT video_projects_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- TOC entry 5022 (class 2606 OID 99042)
--
-- Name: video_assets video_assets_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.video_assets
    ADD CONSTRAINT video_assets_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 5023 (class 2606 OID 99043)
--
-- Name: video_assets video_assets_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.video_assets
    ADD CONSTRAINT video_assets_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.video_projects(id) ON DELETE SET NULL;


--
-- TOC entry 5024 (class 2606 OID 99044)
--
-- Name: video_assets video_assets_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.video_assets
    ADD CONSTRAINT video_assets_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.files(id) ON DELETE SET NULL;


--
-- TOC entry 5025 (class 2606 OID 99045)
--
-- Name: video_assets video_assets_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.video_assets
    ADD CONSTRAINT video_assets_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- TOC entry 5026 (class 2606 OID 99046)
--
-- Name: media_generations media_generations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.media_generations
    ADD CONSTRAINT media_generations_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 5027 (class 2606 OID 99047)
--
-- Name: media_generations media_generations_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.media_generations
    ADD CONSTRAINT media_generations_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.video_projects(id) ON DELETE SET NULL;


--
-- TOC entry 5028 (class 2606 OID 99048)
--
-- Name: media_generations media_generations_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.media_generations
    ADD CONSTRAINT media_generations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- TOC entry 5029 (class 2606 OID 99049)
--
-- Name: render_jobs render_jobs_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.render_jobs
    ADD CONSTRAINT render_jobs_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 5030 (class 2606 OID 99050)
--
-- Name: render_jobs render_jobs_generation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.render_jobs
    ADD CONSTRAINT render_jobs_generation_id_fkey FOREIGN KEY (generation_id) REFERENCES public.media_generations(id) ON DELETE CASCADE;


--
-- TOC entry 5031 (class 2606 OID 99051)
--
-- Name: media_outputs media_outputs_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.media_outputs
    ADD CONSTRAINT media_outputs_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.organizations(id) ON DELETE CASCADE;


--
-- TOC entry 5032 (class 2606 OID 99052)
--
-- Name: media_outputs media_outputs_generation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.media_outputs
    ADD CONSTRAINT media_outputs_generation_id_fkey FOREIGN KEY (generation_id) REFERENCES public.media_generations(id) ON DELETE CASCADE;


--
-- TOC entry 5033 (class 2606 OID 99053)
--
-- Name: media_outputs media_outputs_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.media_outputs
    ADD CONSTRAINT media_outputs_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.render_jobs(id) ON DELETE SET NULL;


--
-- TOC entry 5034 (class 2606 OID 99054)
--
-- Name: media_outputs media_outputs_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.media_outputs
    ADD CONSTRAINT media_outputs_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.files(id) ON DELETE SET NULL;


--
-- TOC entry 5035 (class 2606 OID 99055)
--
-- Name: usage_events usage_events_generation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_generation_id_fkey FOREIGN KEY (generation_id) REFERENCES public.media_generations(id) ON DELETE SET NULL;


--
-- TOC entry 5036 (class 2606 OID 99056)
--
-- Name: usage_events usage_events_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE ONLY public.usage_events
    ADD CONSTRAINT usage_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.render_jobs(id) ON DELETE SET NULL;


--
-- TOC entry 4836 (class 3256 OID 17993)
--
-- Name: ai_requests Admins can update requests; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can update requests" ON public.ai_requests FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 4840 (class 3256 OID 17997)
--
-- Name: usage_events Admins can view usage; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can view usage" ON public.usage_events FOR SELECT USING (public.is_org_admin(org_id));


--
-- TOC entry 4834 (class 3256 OID 17991)
--
-- Name: ai_requests Members can insert requests; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can insert requests" ON public.ai_requests FOR INSERT WITH CHECK (public.is_org_member(org_id));


--
-- TOC entry 4832 (class 3256 OID 17987)
--
-- Name: memberships Members can view memberships in their org; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can view memberships in their org" ON public.memberships FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 4833 (class 3256 OID 17989)
--
-- Name: subscriptions Members can view subscription; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can view subscription" ON public.subscriptions FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 4842 (class 3256 OID 18075)
--
-- Name: org_credit_balances Members view credit balances; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members view credit balances" ON public.org_credit_balances FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 4843 (class 3256 OID 18076)
--
-- Name: credit_transactions Members view credit transactions; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members view credit transactions" ON public.credit_transactions FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 4835 (class 3256 OID 17992)
--
-- Name: ai_requests Members view their org requests; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members view their org requests" ON public.ai_requests FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 5040 (class 3256 OID 99095)
--
-- Name: files Members can view files; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can view files" ON public.files FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 5041 (class 3256 OID 99096)
--
-- Name: files Members can insert files; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can insert files" ON public.files FOR INSERT WITH CHECK (public.is_org_member(org_id));


--
-- TOC entry 5042 (class 3256 OID 99097)
--
-- Name: files Admins can update files; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can update files" ON public.files FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 5043 (class 3256 OID 99098)
--
-- Name: files Admins can delete files; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can delete files" ON public.files FOR DELETE USING (public.is_org_admin(org_id));


--
-- TOC entry 5044 (class 3256 OID 99099)
--
-- Name: file_attachments Members can view file attachments; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can view file attachments" ON public.file_attachments FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 5045 (class 3256 OID 99100)
--
-- Name: file_attachments Members can insert file attachments; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can insert file attachments" ON public.file_attachments FOR INSERT WITH CHECK (public.is_org_member(org_id));


--
-- TOC entry 5046 (class 3256 OID 99101)
--
-- Name: file_attachments Admins can update file attachments; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can update file attachments" ON public.file_attachments FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 5047 (class 3256 OID 99102)
--
-- Name: file_attachments Admins can delete file attachments; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can delete file attachments" ON public.file_attachments FOR DELETE USING (public.is_org_admin(org_id));


--
-- TOC entry 5040 (class 3256 OID 99065)
--
-- Name: video_projects Members can view video projects; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can view video projects" ON public.video_projects FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 5041 (class 3256 OID 99066)
--
-- Name: video_projects Members can insert video projects; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can insert video projects" ON public.video_projects FOR INSERT WITH CHECK (public.is_org_member(org_id));


--
-- TOC entry 5042 (class 3256 OID 99067)
--
-- Name: video_projects Admins can update video projects; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can update video projects" ON public.video_projects FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 5043 (class 3256 OID 99068)
--
-- Name: video_projects Admins can delete video projects; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can delete video projects" ON public.video_projects FOR DELETE USING (public.is_org_admin(org_id));


--
-- TOC entry 5044 (class 3256 OID 99069)
--
-- Name: video_assets Members can view video assets; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can view video assets" ON public.video_assets FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 5045 (class 3256 OID 99070)
--
-- Name: video_assets Members can insert video assets; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can insert video assets" ON public.video_assets FOR INSERT WITH CHECK (public.is_org_member(org_id));


--
-- TOC entry 5046 (class 3256 OID 99071)
--
-- Name: video_assets Admins can update video assets; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can update video assets" ON public.video_assets FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 5047 (class 3256 OID 99072)
--
-- Name: video_assets Admins can delete video assets; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can delete video assets" ON public.video_assets FOR DELETE USING (public.is_org_admin(org_id));


--
-- TOC entry 5048 (class 3256 OID 99073)
--
-- Name: media_generations Members can view media generations; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can view media generations" ON public.media_generations FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 5049 (class 3256 OID 99074)
--
-- Name: media_generations Members can insert media generations; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can insert media generations" ON public.media_generations FOR INSERT WITH CHECK (public.is_org_member(org_id));


--
-- TOC entry 5050 (class 3256 OID 99075)
--
-- Name: media_generations Admins can update media generations; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can update media generations" ON public.media_generations FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 5051 (class 3256 OID 99076)
--
-- Name: media_generations Admins can delete media generations; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can delete media generations" ON public.media_generations FOR DELETE USING (public.is_org_admin(org_id));


--
-- TOC entry 5052 (class 3256 OID 99077)
--
-- Name: render_jobs Members can view render jobs; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can view render jobs" ON public.render_jobs FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 5053 (class 3256 OID 99078)
--
-- Name: render_jobs Admins can insert render jobs; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can insert render jobs" ON public.render_jobs FOR INSERT WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 5054 (class 3256 OID 99079)
--
-- Name: render_jobs Admins can update render jobs; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can update render jobs" ON public.render_jobs FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 5055 (class 3256 OID 99080)
--
-- Name: render_jobs Admins can delete render jobs; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can delete render jobs" ON public.render_jobs FOR DELETE USING (public.is_org_admin(org_id));


--
-- TOC entry 5056 (class 3256 OID 99081)
--
-- Name: media_outputs Members can view media outputs; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Members can view media outputs" ON public.media_outputs FOR SELECT USING (public.is_org_member(org_id));


--
-- TOC entry 5057 (class 3256 OID 99082)
--
-- Name: media_outputs Admins can insert media outputs; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can insert media outputs" ON public.media_outputs FOR INSERT WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 5058 (class 3256 OID 99083)
--
-- Name: media_outputs Admins can update media outputs; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can update media outputs" ON public.media_outputs FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 5059 (class 3256 OID 99084)
--
-- Name: media_outputs Admins can delete media outputs; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Admins can delete media outputs" ON public.media_outputs FOR DELETE USING (public.is_org_admin(org_id));


--
-- TOC entry 4831 (class 3256 OID 17982)
--
-- Name: organizations Organizations are viewable by members; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Organizations are viewable by members" ON public.organizations FOR SELECT USING (public.is_org_member(id));


--
-- TOC entry 4841 (class 3256 OID 18074)
--
-- Name: plan_catalog Plan catalog readable; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY "Plan catalog readable" ON public.plan_catalog FOR SELECT TO authenticated USING (true);


--
-- TOC entry 4851 (class 3256 OID 78308)
--
-- Name: profiles Users can update their profile; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

--
-- TOC entry 4828 (class 0 OID 73744)
--
-- Name: action_costs; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.action_costs ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4824 (class 0 OID 72436)
--
-- Name: addon_catalog; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.addon_catalog ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4826 (class 0 OID 72496)
--
-- Name: addon_features; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.addon_features ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4798 (class 0 OID 17880)
--
-- Name: ai_requests; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.ai_requests ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 5035 (class 0 OID 99060)
--
-- Name: video_projects; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.video_projects ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 5036 (class 0 OID 99061)
--
-- Name: video_assets; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.video_assets ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 5037 (class 0 OID 99062)
--
-- Name: media_generations; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.media_generations ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 5038 (class 0 OID 99063)
--
-- Name: render_jobs; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.render_jobs ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 5039 (class 0 OID 99064)
--
-- Name: media_outputs; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.media_outputs ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4829 (class 0 OID 73764)
--
-- Name: credit_holds; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.credit_holds ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4803 (class 0 OID 18039)
--
-- Name: credit_transactions; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4821 (class 0 OID 72382)
--
-- Name: feature_catalog; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.feature_catalog ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4808 (class 0 OID 26424)
--
-- Name: file_attachments; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.file_attachments ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4807 (class 0 OID 26372)
--
-- Name: files; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.files ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4796 (class 0 OID 17831)
--
-- Name: memberships; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4854 (class 3256 OID 78311)
--
-- Name: memberships memberships_admin_delete; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY memberships_admin_delete ON public.memberships FOR DELETE USING (public.is_org_admin(org_id));


--
-- TOC entry 4852 (class 3256 OID 78309)
--
-- Name: memberships memberships_admin_insert; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY memberships_admin_insert ON public.memberships FOR INSERT WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 4853 (class 3256 OID 78310)
--
-- Name: memberships memberships_admin_update; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY memberships_admin_update ON public.memberships FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 4825 (class 0 OID 72446)
--
-- Name: org_addons; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.org_addons ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4802 (class 0 OID 18014)
--
-- Name: org_credit_balances; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.org_credit_balances ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4823 (class 0 OID 72416)
--
-- Name: org_feature_overrides; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.org_feature_overrides ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4794 (class 0 OID 17792)
--
-- Name: organizations; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4857 (class 3256 OID 78314)
--
-- Name: organizations organizations_admin_delete; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY organizations_admin_delete ON public.organizations FOR DELETE USING (public.is_org_admin(id));


--
-- TOC entry 4855 (class 3256 OID 78312)
--
-- Name: organizations organizations_admin_insert; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY organizations_admin_insert ON public.organizations FOR INSERT WITH CHECK (public.is_org_admin(id));


--
-- TOC entry 4856 (class 3256 OID 78313)
--
-- Name: organizations organizations_admin_update; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY organizations_admin_update ON public.organizations FOR UPDATE USING (public.is_org_admin(id)) WITH CHECK (public.is_org_admin(id));


--
-- TOC entry 4801 (class 0 OID 18002)
--
-- Name: plan_catalog; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.plan_catalog ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4822 (class 0 OID 72392)
--
-- Name: plan_features; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.plan_features ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4827 (class 0 OID 73725)
--
-- Name: plan_prices; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.plan_prices ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4795 (class 0 OID 17809)
--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4850 (class 3256 OID 78307)
--
-- Name: profiles profiles_select; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

-- CREATE POLICY profiles_select ON public.profiles FOR SELECT USING (((EXISTS ( SELECT 1
--    FROM public.memberships m
--   WHERE ((m.profile_id = profiles.id) AND public.is_org_member(m.org_id)))) OR (id = ( SELECT auth.uid() AS uid))));

--
-- TOC entry 4830 (class 0 OID 79481)
--
-- Name: stripe_webhook_events; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.stripe_webhook_events ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4797 (class 0 OID 17859)
--
-- Name: subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4858 (class 3256 OID 78317)
--
-- Name: subscriptions subscriptions_admin_delete; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY subscriptions_admin_delete ON public.subscriptions FOR DELETE USING (public.is_org_admin(org_id));


--
-- TOC entry 4847 (class 3256 OID 78315)
--
-- Name: subscriptions subscriptions_admin_insert; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY subscriptions_admin_insert ON public.subscriptions FOR INSERT WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 4848 (class 3256 OID 78316)
--
-- Name: subscriptions subscriptions_admin_update; Type: POLICY; Schema: public; Owner: -
-- Data Pos: 0
--

CREATE POLICY subscriptions_admin_update ON public.subscriptions FOR UPDATE USING (public.is_org_admin(org_id)) WITH CHECK (public.is_org_admin(org_id));


--
-- TOC entry 4800 (class 0 OID 17938)
--
-- Name: usage_events; Type: ROW SECURITY; Schema: public; Owner: -
-- Data Pos: 0
--

ALTER TABLE public.usage_events ENABLE ROW LEVEL SECURITY;


--
-- TOC entry 4859 (class 6104 OID 16426)
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
-- Data Pos: 0
--

CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');


--
-- TOC entry 3861 (class 3466 OID 16621)
--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
-- Data Pos: 0
--

CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION extensions.set_graphql_placeholder();


--
-- TOC entry 3866 (class 3466 OID 16700)
--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
-- Data Pos: 0
--

CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_cron_access();


--
-- TOC entry 3860 (class 3466 OID 16619)
--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
-- Data Pos: 0
--

CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end
         WHEN TAG IN ('CREATE FUNCTION')
   EXECUTE FUNCTION extensions.grant_pg_graphql_access();


--
-- TOC entry 3867 (class 3466 OID 16703)
--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
-- Data Pos: 0
--

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_net_access();


--
-- TOC entry 3862 (class 3466 OID 16622)
--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
-- Data Pos: 0
--

CREATE EVENT TRIGGER pgrst_ddl_watch ON ddl_command_end
   EXECUTE FUNCTION extensions.pgrst_ddl_watch();


--
-- TOC entry 3863 (class 3466 OID 16623)
--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
-- Data Pos: 0
--

CREATE EVENT TRIGGER pgrst_drop_watch ON sql_drop
   EXECUTE FUNCTION extensions.pgrst_drop_watch();


-- Completed on 2026-01-09 12:41:45

--

--




