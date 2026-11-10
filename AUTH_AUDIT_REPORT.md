# Authentication Audit and Fix Report

## Scope inspected

- `home.html` login modal and `signup.html` registration form
- `scripts/auth.js` frontend request handlers
- `server/index.js` Express API, MySQL connection, password verification, and sessions
- `database/pilipinastravel.sql` user, role, and permission schema
- `database/authentication.sql` registration/login procedures and session table
- `AUTH_SETUP.md` setup instructions

## Findings

1. The API login route depends on `sp_get_login_credentials`, which is created only by `database/authentication.sql`. Importing only the main schema leaves the login API calling a procedure that does not exist.
2. The frontend used a fixed `http://localhost:3000` API URL. When Live Server was opened at `127.0.0.1`, browser cookie/CORS behavior could differ because the API host remained `localhost`.
3. After a successful login, the frontend only displayed a success message. It did not navigate to an authenticated landing page.
4. The login API did not return role information, and `/api/auth/me` did not include roles. The frontend therefore could not select a dashboard based on the authenticated user's role.
5. The schema supported `ADMIN`, `TRAVELER`, and `LOCAL_HOST`, but did not include the requested `STAFF` role. No role-aware dashboard page existed in the supplied source package.
6. Existing account rows without a role, inactive account status, or a non-bcrypt password value can still prevent authentication. Those data states must be checked rather than bypassed.

## Changes implemented

- Added role retrieval and a consistent primary-role priority: `ADMIN`, `STAFF`, `LOCAL_HOST`, `TRAVELER`.
- Included `roles` and `primaryRole` in successful login and current-session API responses.
- Kept bcrypt verification server-side and rejected malformed/non-bcrypt stored hashes safely.
- Kept account lockout, active-account checks, hashed session tokens, HTTP-only cookies, and parameterized SQL.
- Made the frontend API URL follow the frontend hostname by default, with an optional `auth-api-url` meta override.
- Redirected successful logins to a role-specific section of `dashboard.html`.
- Added a dashboard that checks `/api/auth/me`, displays the authenticated user's identity and role, and supports logout.
- Added the `STAFF` role to the fresh schema and an idempotent existing-database role/permission migration.
- Assigned `TRAVELER` to pre-existing accounts that have no role assignment, while preserving accounts with explicit roles.
- Added clearer API errors when authentication database tables, columns, or procedures are missing.
- Updated `AUTH_SETUP.md` with installation, migration, account diagnostic, and role assignment instructions.

## Validation performed

- `node --check server/index.js` passed.
- `node --check scripts/auth.js` passed.
- `node --check scripts/dashboard.js` passed.
- Local HTML asset references were checked; all referenced local files exist.
- Static checks confirmed that the login route, stored procedure, session table, bcrypt field, role migration, and role response are present.

## Runtime validation still required

A live MySQL server and the project's actual `.env` credentials were not available in the supplied source archive. Therefore, a real database login, registration, cookie round trip, and role redirect could not be executed in this environment.

Follow `AUTH_SETUP.md` on the machine running MySQL. For an existing database, do not rerun `database/pilipinastravel.sql`; run `database/authentication.sql` after confirming the main schema exists.

## Important compatibility notes

- The supplied schema has an `email` column, not a `username` column. This fix intentionally keeps email-based login and does not silently add a username field.
- New accounts receive `TRAVELER` and `ACTIVE` status with a bcrypt hash.
- Existing accounts need `ACTIVE` status, a compatible bcrypt hash, and at least one role. The migration assigns `TRAVELER` only where an account has no role at all.
- Plaintext or unsupported password hashes must be migrated through a secure password-reset process. This project does not currently include password reset.
- The dashboard is role-aware, but the supplied application does not include complete user-management/staff screens or protected management endpoints. Backend permission checks must be added to any future privileged API routes; hiding UI links is not sufficient authorization.
