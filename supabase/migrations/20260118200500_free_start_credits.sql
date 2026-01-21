-- Increase free plan starter credits to 100 and top up existing free orgs.
UPDATE public.plan_catalog
SET free_weekly_credits = 100
WHERE plan_code = 'free_v1';

UPDATE public.org_credit_balances
SET
  free_credits_available = GREATEST(free_credits_available, 100),
  last_free_refill_at = timezone('utc', now()),
  next_free_refill_at = timezone('utc', now()) + INTERVAL '7 days',
  updated_at = timezone('utc', now())
WHERE plan_code = 'free_v1'
  AND free_credits_available < 100;
