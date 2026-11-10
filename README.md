# GenZBag

**Discover Opportunities. Complete Tasks. Earn Real Money.**

GenZBag is a planned online rewards platform. This repository contains the application source code and project documentation.

## Development principles

- Build and test with simulated balances and payment records first.
- Only record rewards after a genuine, independently verified qualifying event and available platform revenue.
- Referral commissions must never be funded merely by recruitment or membership payments.
- Keep payment integrations disabled until appropriate business, legal, consumer-protection, and adult oversight requirements are met.
- Protect account credentials and personal data; never commit production databases, passwords, API keys, or private credentials.

## Planned modules

1. Account registration and secure authentication
2. User profiles and unique referral links
3. User dashboard
4. Admin dashboard and audit records
5. Tasks and verified reward records
6. Activation and withdrawal records (test mode initially)
7. Notifications and support

## Local development

Use a Python virtual environment. Install dependencies from `requirements.txt` when that file is added, then follow the setup instructions documented for each module.

## Data safety

Local SQLite databases (including `users.db` and backups), virtual environments, environment files, keys, and logs are excluded from Git. Back up local data separately and do not upload real user information to this repository.

## Status

Early development. Features and payment flows are not production-ready.
