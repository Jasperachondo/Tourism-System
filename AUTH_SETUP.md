# Login and sign-up setup

The HTML pages are served by VS Code Live Server. Authentication is handled by a
separate Node.js API and a MySQL 8 database.

## 1. Install the database schema and authentication routines

Start MySQL. For a **new, empty installation**, run these scripts from the
project folder in this order:

```sh
mysql -u root -p < database/pilipinastravel.sql
mysql -u root -p < database/authentication.sql
```

Alternatively, execute each SQL file in MySQL Workbench. The first script creates
the main schema and seeds `ADMIN`, `TRAVELER`, `LOCAL_HOST`, and `STAFF`. The
authentication script creates the session table and stored procedures. It also
adds the `STAFF` role and its permissions to an existing installation if needed,
and assigns `TRAVELER` to older accounts that do not yet have a role. Existing
explicit role assignments are preserved.

**Important for an existing database:** do not rerun `database/pilipinastravel.sql`
against a database whose tables and sample data already exist. That file creates
tables and seeds data without being a repeatable migration. After confirming the
main schema is present, run only `database/authentication.sql` to install or update
the authentication objects.

Run the authentication script again after updating it. It is designed to recreate
the authentication procedures and preserve existing session records.

## 2. Configure and start the API

Install Node.js 18 or newer, then in the project folder:

```sh
npm install
cp .env.example .env
```

Edit `.env` with the MySQL username and password that can access
`pilipinas_travel`. Keep `.env` private; it is excluded from Git.

Start the API:

```sh
npm start
```

The API listens on `http://localhost:3000`. Keep this terminal running. You can
verify database connectivity by opening `http://localhost:3000/api/health`.

## 3. Open the website

Open `home.html` with VS Code Live Server, then use **Sign Up** or **Login**.
The API URL follows the hostname used by the frontend, so use the same host for
both services (for example, `localhost` for both or `127.0.0.1` for both). The API
allows the default Live Server ports 5500 and 5501. If Live Server chooses another
port, add its exact origin to `FRONTEND_ORIGINS` in `.env` and restart the API.

For a different API host or port, add this tag to the HTML page's `<head>`:

```html
<meta name="auth-api-url" content="http://localhost:3000/api/auth">
```

Successful sign-ins redirect to `dashboard.html`. The dashboard loads the
current session from `/api/auth/me` and displays role-specific information for
`ADMIN`, `STAFF`, `LOCAL_HOST`, or `TRAVELER`. The current source package does not
yet include complete user-management or staff-operation screens; the role-aware
dashboard is the authenticated landing page, not a substitute for server-side
permission checks on future management APIs.

## 4. Assign an administrator or staff role

New sign-ups automatically receive the `TRAVELER` role. To assign a role to an
existing account, use MySQL Workbench or the MySQL client. Replace the email with
the account's registered email address.

```sql
-- Add ADMIN access to an existing account.
INSERT INTO user_roles (user_id, role_id)
SELECT u.user_id, r.role_id
FROM users u
JOIN roles r ON r.role_name = 'ADMIN'
WHERE u.email = 'admin@example.com'
ON DUPLICATE KEY UPDATE granted_at = CURRENT_TIMESTAMP;

-- Add STAFF access to an existing account.
INSERT INTO user_roles (user_id, role_id)
SELECT u.user_id, r.role_id
FROM users u
JOIN roles r ON r.role_name = 'STAFF'
WHERE u.email = 'staff@example.com'
ON DUPLICATE KEY UPDATE granted_at = CURRENT_TIMESTAMP;
```

The API chooses the primary role in this order: `ADMIN`, `STAFF`, `LOCAL_HOST`,
then `TRAVELER`. If an account has multiple roles, all are returned by the API.

## 5. Troubleshoot an account that still cannot log in

Run this query to check the account state and stored password format without
printing the password hash:

```sql
SELECT
    u.user_id,
    u.email,
    u.account_status,
    u.failed_login_attempts,
    u.locked_until,
    CASE
        WHEN u.password_hash REGEXP '^\\$2[aby]\\$' THEN 'BCRYPT_HASH'
        ELSE 'NOT_BCRYPT_HASH'
    END AS password_format,
    GROUP_CONCAT(r.role_name ORDER BY r.role_name) AS roles
FROM users u
LEFT JOIN user_roles ur ON ur.user_id = u.user_id
LEFT JOIN roles r ON r.role_id = ur.role_id
WHERE u.email = LOWER(TRIM('traveler@example.com'))
GROUP BY u.user_id;
```

An account must have `account_status = 'ACTIVE'`, a bcrypt password hash created
by the application, and at least one assigned role. The application locks an
account for 15 minutes after five failed password attempts. Do not store plaintext
passwords or weaken verification to accommodate old plaintext records. Accounts
with plaintext or unsupported password hashes require a secure password-reset
process; the current project does not yet implement password reset.

The login form currently accepts email addresses only because the database has
no username column. Do not enter a username unless a username field and matching
backend/database support are added deliberately.
