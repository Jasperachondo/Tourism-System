# Login and sign-up setup

The HTML pages are served by VS Code Live Server. Authentication is handled by a
separate Node.js API and a MySQL 8 database.

## 1. Create the database

Start MySQL, then run these scripts from the project folder, in this order:

```sh
mysql -u root -p < database/pilipinastravel.sql
mysql -u root -p < database/authentication.sql
```

Alternatively, execute each SQL file in MySQL Workbench. The main database
script seeds the `TRAVELER` role, which sign-up requires.

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

The API listens on `http://localhost:3000`. Keep this terminal running.

## 3. Use the site

Open `home.html` with VS Code Live Server, then use **Sign Up** or **Login**.
The API allows the default Live Server ports 5500 and 5501. If Live Server
chooses another port, add its exact origin to `FRONTEND_ORIGINS` in `.env` and
restart the API.

Passwords are hashed by the API before being stored. Successful logins create
an HTTP-only session cookie; the browser never receives the password hash.
