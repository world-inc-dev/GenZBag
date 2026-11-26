# GenZBag production security and scale-readiness runbook

Project reference: `pihesnxftmrzmsoikvfz`

This runbook separates repository deployment from Supabase production changes. A successful GitHub Pages deployment does not deploy SQL or Supabase Edge Functions.

## 1. Database changes (Supabase SQL Editor)

Run these in order, after confirming the project reference is the intended production project:

1. `database/patches/20261126_scale_readiness_indexes.sql`
2. `database/patches/20261126_edge_rate_limiting.sql`

The first patch adds query indexes. The second creates the private rate-limit store and the RPCs used by the public Edge Functions. The second patch is required before deploying the updated sign-in function.

After applying the rate-limit patch, verify the functions exist:

```sql
select routine_schema, routine_name, data_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'consume_edge_rate_limit',
    'consume_signup_availability_rate_limit'
  )
order by routine_name;
```

## 2. Deploy Supabase Edge Functions

From the repository root, after installing and authenticating the Supabase CLI:

```bash
supabase link --project-ref pihesnxftmrzmsoikvfz
supabase functions deploy username-signin --project-ref pihesnxftmrzmsoikvfz
supabase functions deploy signup-availability --project-ref pihesnxftmrzmsoikvfz
supabase functions deploy admin-management --project-ref pihesnxftmrzmsoikvfz
supabase functions list --project-ref pihesnxftmrzmsoikvfz
```

Do not paste service-role keys into source files, GitHub commits, or chat. Keep secrets in Supabase Edge Function secrets.

## 3. Referral and commission integrity

Run `database/diagnostics/20261126_referral_commission_audit.sql` in the SQL Editor and review its result sets before changing referral or commission logic.

The audit is read-only. It reports schema, trigger/function definitions, missing uplines, referral cycles, duplicate ledger idempotency keys, and high-level activation/commission counts.

Do not manually credit a member just because an upline was assigned after activation. First establish the intended eligibility rule, whether historical commissions are payable, the ledger's idempotency convention, and whether an existing trigger already created the credit. Any repair should be a separately reviewed, idempotent transaction with an audit record.

## 4. Browser origin

The Edge Functions currently allow the GitHub Pages origin:

`https://world-inc-dev.github.io`

If the production site is accessed through a custom domain, update the CORS allow-origin value in all three Edge Functions to the exact production origin before deploying them. CORS is not authentication; server-side authorization and database permissions remain mandatory.

## 5. One-million-member readiness

One million registered accounts is a capacity target, not a verified limit. Before making a capacity claim, measure:

- registered accounts, monthly active accounts, and peak concurrent sessions separately;
- p95/p99 latency for sign-in, profile, referral-tree, task, and wallet queries;
- database CPU, memory, connection pool saturation, disk/IO, and query plans;
- Edge Function error rates, execution time, throttling, and cold-start behaviour;
- realtime connection counts and bandwidth;
- backup restoration time and point-in-time recovery;
- load behaviour at staged traffic levels with realistic read/write ratios.

Use a staging project and synthetic accounts for load tests. Never run destructive or high-volume tests against production member or wallet data.

## 6. Current deployment boundary

GitHub Actions validates the repository and deploys the static GitHub Pages site. It cannot apply Supabase SQL or deploy Supabase Edge Functions. Mark the Supabase steps complete only after the SQL has run successfully and the deployed function versions have been verified in Supabase.
