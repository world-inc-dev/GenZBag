# GenZBag

**Discover Opportunities. Complete Tasks. Track Verified Rewards.**

GenZBag is a mobile-first activities and rewards platform built for Uganda, Nigeria and the wider African market.

## Live project

- **Website:** https://world-inc-dev.github.io/GenZBag/
- **Source repository:** https://github.com/world-inc-dev/GenZBag
- **Frontend hosting:** GitHub Pages
- **Backend:** Supabase project (PostgreSQL, Auth, RLS and Edge Functions)

## Architecture

- Static single-page frontend in `index.html`.
- Supabase Auth for registration, email/password sign-in, username sign-in and password reset.
- PostgreSQL tables and database functions for member profiles, referrals, activities, task submissions, reward ledger, withdrawals, messaging, notifications, vouchers and administrator audit records.
- Edge Function source is versioned under `supabase/functions/`, with deployment settings in `supabase/config.toml`.
- Edge Functions:
  - `username-signin` — resolves a username to its account email and authenticates with Supabase Auth.
  - `signup-availability` — performs registration availability checks behind a server-side IP rate limit.
  - `admin-management` — verifies the trusted administrator claim and performs privileged management actions.
- Browser code must contain only the Supabase publishable/anon key. Never commit a service-role key, password, OTP, mobile-money PIN or other secret.

## Member features

- Account registration, sign-in, password reset and profile.
- Referral links, direct referral bonus status and referral network.
- Published sponsored activities, video views, music listening and timed challenges.
- Server-issued Math, Colour and Trivia challenge questions.
- Task submissions and administrator review.
- Reward history, available-balance view and net-profit tracking.
- Mobile-money withdrawal requests, status history and eligibility checks.
- Vouchers, client activation support, notifications and member messaging.

## Activity and reward rules

- Video viewing: maximum 5 starts per Kampala calendar day; reward timer is 60 seconds.
- Music listening: maximum 3 starts per Kampala calendar day; reward timer is 69 seconds.
- Daily Tap Earnings and Spin & Win limits are enforced by database functions.
- Math and Colour challenges use server-issued questions and require a perfect score to qualify for the displayed UGX 1,000 reward.
- Trivia Challenge uses server-issued questions and requires a perfect score to qualify for UGX 3,000.
- Challenge rewards are credited only after administrator approval.
- Some activity rewards are scheduled for a configured weekday. The member wallet releases eligible scheduled credits when it refreshes.
- The UGX 10,500 direct-referral bonus is a one-time bonus for 30 direct referrals and is credited to the available-balance ledger category.

All reward rules are implemented in database functions; browser-side timers and labels are not the authority for eligibility. A ledger credit is not proof of cash reserves or a completed payout.

## Wallet and withdrawals

The member's **Available Balance** is calculated from referral commission credits and the corresponding withdrawal, reversal, voucher-purchase and client-activation ledger entries. Task rewards and welcome bonuses are tracked separately and are not automatically withdrawable.

The withdrawal flow:
1. Checks activation, at least 3 active direct referrals, minimum amount, network, mobile number and available balance.
2. Reserves the requested amount plus the configured 0.80% service fee in the reward ledger.
3. Creates a withdrawal request for administrator review.
4. Returns reserved funds through a ledger reversal if the request is rejected.
5. Allows an administrator to mark an approved request as paid only after entering a transaction reference.

**Important:** GenZBag does not currently have an automated MTN or Airtel payout-provider integration. A withdrawal request is not a payment. An administrator must execute any real transfer separately through an approved provider and record the genuine transaction reference. Do not advertise wallet credits as guaranteed cash or claim that a payout occurred merely because a request was submitted or approved.

## Administrator console

Administrator access depends on the trusted Supabase Auth `app_metadata.role=admin` claim. Do not assign admin access through user-editable metadata or browser code.

The administrator console supports:
- Activity and task management.
- Submission review and reward approval.
- Member and activation review.
- Withdrawal review, rejection/refund and recording of a completed manual payout.
- Financial summary and platform records.
- Support and audit history.
- Member profile administration and email delivery actions.

Privileged administrator actions must remain behind the `admin-management` Edge Function or database functions that verify the trusted administrator claim. Never grant administrator rights from the frontend.

## Database security and recent hardening

The Supabase project has RLS enabled on application tables. Recent hardening includes:
- Enabling RLS on private challenge and activity-session tables.
- Adding missing foreign-key indexes and optimising selected RLS policies.
- Restricting the signup-availability database function to the service role; the public frontend now calls the rate-limited `signup-availability` Edge Function.
- Enforcing Kampala-day video and music limits in database functions, with transaction-level locks to prevent simultaneous requests bypassing the limits.
- Correcting the direct-referral bonus ledger entry type.
- Including pending scheduled rewards in the administrator financial summary.
- Publishing the Math and Colour challenge task records required by the secure challenge session function.

The Supabase migration history contains the applied changes. Before a buyer rebuilds the backend in another Supabase project, export and version the complete migration SQL, Edge Function source, Auth configuration and any required secrets through a secure handover process. The README and migration names alone are not a database backup.

## Deployment

The live frontend is deployed from the `main` branch using GitHub Pages. After a commit, confirm the corresponding Pages build in GitHub Actions before describing the change as deployed.

In Supabase Authentication → URL Configuration, configure:
- Site URL: `https://world-inc-dev.github.io/GenZBag/`
- Allowed redirect URLs: include the same live URL.

Confirm email delivery, password reset and signup redirects after any environment transfer.

## Known production-readiness requirements

GenZBag is an active software project, not yet a verified profitable business or a fully production-certified financial service. Before operating at scale or completing a sale, the owner/buyer should:
1. Enable Supabase leaked-password protection under Authentication → Sign In / Providers → Email → Prevent use of leaked passwords, if the project plan supports it (Supabase Pro and above), and review the remaining Auth security settings.
2. Complete a function-by-function review of the authenticated SECURITY DEFINER functions. They are used by member workflows and must not be indiscriminately revoked.
3. Run end-to-end tests with separate member and administrator accounts, including signup, referrals, challenges, task approvals, wallet reconciliation, voucher purchases, withdrawal rejection/refund and manual payout recording.
4. Configure a real email sender and test delivery.
5. Obtain the appropriate payment-provider approval, business/legal advice, consumer-protection and fraud controls before any real-money payout or financial promotion.
6. Reconcile actual cash receipts, platform income, member liabilities, expenses and payouts independently. Database ledger credits are not proof of bank or mobile-money funds.
7. Export a verified database backup, all migrations and Edge Function source, and prepare a secure transfer of GitHub/Supabase ownership and secrets.

## Legacy prototype files

`registration.py` and `setup_genzbag.py` are retained as early FastAPI/SQLite prototype material. GitHub Pages does not execute Python; the current browser application uses Supabase.

## Sale handover

See [`SALE_HANDOVER.md`](SALE_HANDOVER.md) for the point-in-time technical inventory, database activity snapshot, money-movement limitations, security status and buyer due-diligence checklist.

A complete transfer should include the GitHub repository and Pages configuration, Supabase project ownership, full database migration/export, Edge Function source, Auth/redirect/email configuration, domain or DNS assets if any, third-party content licences, financial reconciliation, and a written list of known limitations. Transfer secrets directly to the buyer using a secure method; never put them in this repository.

A buyer should independently verify the source, database, user permissions, financial records, third-party licences and legal obligations before accepting the platform.
