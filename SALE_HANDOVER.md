# GenZBag — Technical and Sale Handover Notes

**Snapshot date:** 16 November 2026  
**Purpose:** Initial technical due-diligence notes for a prospective full-ownership buyer.  
**Important:** This is an operational snapshot, not an audited financial statement, independent valuation, legal opinion or proof of cash reserves.

## 1. Asset overview

- Product: GenZBag, a mobile-first activities and rewards web platform.
- Live frontend: https://world-inc-dev.github.io/GenZBag/
- Source: https://github.com/world-inc-dev/GenZBag
- Hosting: GitHub Pages.
- Backend: Supabase Auth, PostgreSQL, Row Level Security and Edge Functions.
- Frontend entry point: `index.html`.
- Supabase Edge Function source is versioned under `supabase/functions/`; configuration is in `supabase/config.toml`.

## 2. Implemented modules

- Member registration, email/password authentication, username sign-in and password reset.
- Member profiles and referral network.
- Activity discovery, sponsored tasks and proof submissions.
- Video viewing and music listening rewards with server-side daily limits.
- Server-issued Math, Colour and Trivia challenges.
- Reward ledger, available-balance and net-profit displays.
- Direct referral bonus, vouchers and downline activation contribution flows.
- Withdrawal request creation, administrator review, rejection reversal and manual payout-reference recording.
- Private member messaging, notifications and support functions.
- Administrator console, financial summary and audit logging.

## 3. Security and operational work completed

- Enabled RLS on private challenge/activity tables.
- Added explicit deny policies to internal tables not intended for direct client access.
- Added missing foreign-key indexes and optimised selected RLS policies.
- Removed anonymous/authenticated access to the signup-availability database RPC; public availability checks now use a rate-limited Edge Function.
- Added transaction-level locks to daily video/music starts.
- Corrected the direct referral bonus ledger entry type.
- Aligned wallet available-balance calculations with server-side withdrawal eligibility.
- Added missing Math and Colour challenge task records and corrected post-submission challenge refresh behaviour.
- Non-qualifying challenge attempts are automatically closed with no reward; perfect scores are sent for administrator review.
- Added pending scheduled rewards to the administrator financial summary.
- Removed direct client access to an obsolete test-withdrawal RPC.
- Versioned the active Edge Function source and configuration in the repository.

## 4. Point-in-time database activity

The live database snapshot on 16 November 2026 reported:

| Measure | Database records |
|---|---:|
| Registered profiles | 5 |
| Verified activation submissions | 2 |
| Total amount on verified activations | UGX 19,500 |
| Verified paid mobile-money activations | 1 |
| Amount on verified paid mobile-money activations | UGX 19,500 |
| Platform income ledger | 2 entries totalling UGX 7,000 |
| Referral commission credits | 1 entry totalling UGX 10,500 |
| Task reward credits | 10 entries totalling UGX 3,400 |
| Welcome bonus credits | 1 entry totalling UGX 5,000 |
| Withdrawal requests | 0 |
| Pending scheduled task rewards | UGX 0 |
| Published tasks after challenge repair | 10 |

These are database counts and ledger entries only. They do not establish net profit, cash at bank/mobile money, customer retention, repeat usage, payout history or a sustainable revenue model. The second verified activation record is not counted as paid mobile-money activation income in the paid-income measure.

## 5. Money movement limitations

- The withdrawal form creates a request and reserves the requested amount plus the configured 0.80% fee in the ledger.
- Rejected requests return the reserved amount through a ledger reversal.
- An administrator can record a paid request only after entering a mobile-money transaction reference.
- There is no automated MTN or Airtel payout-provider integration.
- A request or approval is not proof that a transfer occurred.
- Activity and reward credits are not proof of external funding or guaranteed cash.
- No prospective buyer should rely on dashboard totals alone; reconcile bank/mobile-money statements, activation records, platform income, ledger balances, outstanding liabilities and expenses independently.

## 6. Current security-advisor status

The latest Supabase Security Advisor run reports:
- 21 authenticated-callable SECURITY DEFINER functions. Member-facing functions use the authenticated user's identity for scoping; administrator functions check trusted role claims or service-role access. The linter still flags these functions because authenticated users can invoke them; retain the function-level authorization checks and re-review them before material changes.
- Leaked-password protection remains disabled. Supabase documents this setting under Authentication → Sign In / Providers → Email; it is available on Pro and above.
- No remaining anonymous-callable SECURITY DEFINER warning.
- No remaining RLS-enabled-without-policy informational findings after explicit deny policies were added.
- Performance advisor reports unused indexes, which are informational on a low-activity database and should not be removed without workload evidence.

## 7. Before a full sale or production launch

1. Enable leaked-password protection if the Supabase plan supports it; review Auth password requirements, email confirmation, redirect URLs, SMTP and rate limits.
2. Complete real-device end-to-end tests using separate member and administrator accounts.
3. Verify signup, password reset, referrals, challenges, activity limits, scheduled credits, wallet calculations, voucher purchases, withdrawal rejection/refund and manual payout recording.
4. Independently reconcile all receipts, platform income, liabilities, expenses and any actual payouts.
5. Confirm third-party content rights and licences for every music/video/ad asset.
6. Obtain appropriate Ugandan and target-market legal, tax, consumer-protection and payment-provider advice before operating a real-money rewards or payout service.
7. Export a verified Supabase database backup and the complete SQL migration history. The repository's existing patch files and migration names are not a substitute for a full database export.
8. Transfer GitHub repository/organization ownership, GitHub Pages settings, Supabase project ownership, Auth configuration, Edge Function secrets, email-provider configuration and any domain/DNS assets securely.
9. Rotate credentials and verify that the buyer's accounts have sole owner/admin control after transfer.

## 8. Valuation caution

A target asking price is a seller's position, not an independently supported market valuation. The current database activity is very small and does not by itself substantiate a UGX 15 million-plus sale price. A buyer is more likely to value the software, working features, documentation, defensible intellectual property, verified revenue, active users, retention, compliance status and ability to operate independently.
