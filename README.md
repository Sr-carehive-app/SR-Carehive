
# Serechi

A Flutter + Node (Express) application for the SR CareHive patient & provider platform.

This repository contains a Flutter client (mobile/web) and a lightweight Node server used for transactional emails, payment notifications and small server-side helpers. A Supabase (Postgres) backend is used for authentication, database and storage.

---

## Quick project overview

- Flutter client: `lib/` (screens, widgets, services, models)
- Node backend: `server.js` (email templates, notify endpoints, payment helpers)
- Database: PostgreSQL (Supabase) — tables include `patients`, `appointments`, `payments`, etc.
- Payment integration: Razorpay (client + small server helpers)

---

## Recent important changes

The following changes were applied during recent development and are present in the repository:

- Registration fee changed from ₹100 → ₹10 in business logic and SQL views/functions:
	- SQL: `database_update_payment_flow.sql`, `database_update_payment_flow_FIXED.sql`, `USEFUL_SQL_QUERIES.sql` updated.
	- Client: `lib/models/payment_models.dart` and `lib/services/payment_service.dart` reflect ₹10.
	- Server: `server.js` uses `appointment.amount_rupees || 10` as a fallback where appropriate.
- Replaced Date of Birth (DOB) form input with an Age numeric field in relevant signup/profile flows; removed Street input from visible Permanent Address forms and stopped persisting it.
- Top-left avatar on patient dashboard now navigates to the Profile tab.
- Missing `intl` import added to `lib/screens/patient/patient_login_screen.dart` to support `DateFormat` used when pre-filling sign-up data.

If you'd like registration amount to be configurable (env var or DB), I can implement that next.

---

## Prerequisites (local development)

- Flutter (stable channel) — https://docs.flutter.dev/get-started/install
- Node.js (v16+) and npm/yarn
- Supabase account (recommended) or local Postgres for DB
- Optional: `nodemon` for faster server iteration

---

## Running the Flutter client

From project root:

```powershell
flutter pub get
flutter analyze
flutter run -d chrome --web-port=5173
```

Notes:
- If analyzer reports missing imports for `DateFormat`, ensure `package:intl` is imported in the file (we added it to `patient_login_screen.dart`).
- If you want to update package versions, run `flutter pub outdated` then `flutter pub upgrade` where safe.

---

## Running the Node server

Install and start:

```powershell
npm install
# start with auto-reload
nodemon server.js
# or run directly
node server.js
```

Set required environment variables for Supabase, SMTP, and Razorpay (check `server.js` and your deployment env).

---

## Database & migrations (Supabase/Postgres)

- SQL migration files live at the repository root (prefix `database_*`).
- Important files for payment flow and registration:
	- `database_update_payment_flow.sql`
	- `database_update_payment_flow_FIXED.sql`
	- `database_migration_registration_fields.sql`
	- `USEFUL_SQL_QUERIES.sql`

Add `age` safely (no dummy data) example:

```sql
ALTER TABLE patients
ADD COLUMN IF NOT EXISTS age INTEGER;

ALTER TABLE patients
ADD CONSTRAINT chk_patients_age_range CHECK (age IS NULL OR (age >= 0 AND age <= 120));
```

Backfill from an existing `dob` (only if `dob` is DATE typed):

```sql
UPDATE patients
SET age = DATE_PART('year', AGE(dob))
WHERE dob IS NOT NULL AND (age IS NULL OR age <> DATE_PART('year', AGE(dob)));
```

Always backup the DB before schema changes.

---

## How the registration fee change was validated

1. Searched the codebase for registration/payment logic that referenced `100`.
2. Updated SQL views/functions to compute totals using `10` for the registration portion.
3. Updated Dart client payment model and service constants to `10.0`.
4. Left unrelated `100` usages (UI sizes, timeouts, paise multipliers) unchanged intentionally.

If you want to enforce a single source of truth, I can refactor the code to read `REGISTRATION_AMOUNT` from a central config (env var or DB) and replace in the codebase.

---

## Files I edited (quick review)

- `lib/screens/patient/patient_dashboard_screen.dart` — avatar navigation
- `lib/screens/patient/profile/edit_profile_screen.dart` — DOB → Age, remove Street persistence
- `lib/screens/patient/patient_signup_screen.dart` — ensured `age` is included in signup payloads
- `lib/screens/patient/patient_login_screen.dart` — added `import 'package:intl/intl.dart';`
- `lib/models/payment_models.dart` — registration amount logic set to 10
- `lib/services/payment_service.dart` — `REGISTRATION_AMOUNT = 10.0`
- `server.js` — notification templates already fall back to 10; left as-is
- `database_update_payment_flow.sql` & `database_update_payment_flow_FIXED.sql` & `USEFUL_SQL_QUERIES.sql` — updated registration logic

---

## Verification checklist (recommended)

1. `flutter analyze` — fix any reported Dart analyzer issues.
2. `flutter run` → test signup/login/profile flows and check that registration payment flows are ₹10.
3. Start server and simulate registration payment flow to validate emails and DB write (`registration_paid`, `registration_payment_id`, etc.).
4. Run these SQL queries to verify the view/function:

```sql
SELECT * FROM appointment_payment_summary LIMIT 5;
SELECT get_pending_payment(<<some_appointment_id>>);
```

---

## Next steps I can do for you

- Run `flutter analyze` in this environment and fix any errors automatically.
- Make registration fee configurable (env var or DB setting).
- Implement a staged DB migration to backfill `age` from `dob` and then drop legacy columns when you're ready.

---

If you want me to run the analyzer and fix any remaining issues now, tell me and I will run `flutter analyze` and address the first reported errors.

Thank you — tell me which next action you want me to take.
