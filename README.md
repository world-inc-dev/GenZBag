# GenZBag

**Discover Opportunities. Complete Tasks. Track Verified Rewards.**

GenZBag is an online activities and rewards platform being built for Uganda, Nigeria and the wider African market.

## Current architecture

- **Frontend:** Static, mobile-responsive web application hosted with GitHub Pages.
- **Backend:** Supabase Auth and PostgreSQL.
- **Database security:** Row Level Security enabled across all application tables.
- **Public browser credential:** Supabase publishable key only. Never place a Supabase secret/service-role key in browser code or GitHub.
- **Payments:** Test mode only. Real payouts are disabled.

## Current member features

- Email registration, sign-in and password reset.
- User profile and preferred currency.
- Published activity/task discovery and proof submission.
- Submission status and activity history.
- Wallet balance view based on the reward ledger.
- Referral code and invitation link.
- Test withdrawal request records.
- Notifications and support tickets.

## Database modules

The Supabase project includes profiles, tasks, task submissions, referrals, reward ledger, withdrawal requests, notifications, support tickets, platform settings and administrator audit logs. New accounts receive a profile and unique referral code through a database trigger.

Administrator access is based on trusted Supabase Auth app_metadata claims, not user-editable metadata. Admin claims must only be assigned through a trusted administrative process.

## Deployment

- Repository: https://github.com/world-inc-dev/GenZBag
- GitHub Pages site: https://world-inc-dev.github.io/GenZBag/

In the Supabase Dashboard, configure Authentication → URL Configuration:
- Site URL: https://world-inc-dev.github.io/GenZBag/
- Add the same URL to the allowed redirect URLs.

Email confirmation settings are controlled in Supabase Authentication. Test registration and confirmation after configuring the redirect URL.

## Development and financial safety

- Start with simulated balances and test withdrawal requests.
- Users must never be able to credit their own reward balances.
- Record a reward only after an independently verified qualifying activity and sufficient genuine platform revenue.
- Referral commissions must not be funded merely by recruitment or membership payments.
- Do not activate real money transfers until payment-provider approval, business/legal requirements, consumer-protection controls, fraud controls and operational reconciliation are ready.
- Never request or commit passwords, OTPs, mobile-money PINs, production databases, Supabase secret keys or service-role keys.

## Legacy prototype files

registration.py and setup_genzbag.py are retained as early FastAPI/SQLite prototype material. GitHub Pages does not execute Python. The current browser application uses Supabase directly.

## Status

The Supabase database foundation, responsive member portal and administrator console are in place. The administrator console is visible only to authenticated users whose trusted Supabase Auth `app_metadata.role` claim is `admin`.

## Administrator console
- Create and publish activities.
- Review member submissions.
- Approve or reject submissions through the `admin_review_task_submission` database function.
- Approved tasks create an idempotent test-wallet ledger credit.
- Review member accounts, withdrawal requests, support tickets and the audit trail.
- Admin actions are protected by database RLS and recorded in `admin_audit_logs`.

Do not assign administrator access through editable user metadata or from browser code. Grant the `app_metadata.role=admin` claim only through a trusted Supabase administrative process.

## Test-mode controls
- The member withdrawal form calls `create_test_withdrawal_request`, which checks the available ledger balance and prevents duplicate pending requests in the same currency.
- Withdrawal requests are records only. No mobile-money or bank transfer is executed.
- Task rewards are simulated wallet credits. Do not advertise them as cash or payable funds until genuine revenue funding, provider approval, reconciliation and legal/compliance readiness are complete.
- The browser receives only the Supabase publishable key. Keep all secret/service-role keys outside the repository and browser.
