# Centia.io Docker

This repository provides a Docker-based setup for running the Centia.io stack with FrankenPHP (Caddy), 
PostgreSQL/PostGIS, and Redis. 
It includes two app services (HTTP and WebSocket), a Postgres/PostGIS database, and Redis for caching.

After installation, you can access the system with the CLI:

```bash
npm install -g @centia-io/cli
centia connect http://localhost:81
centia login
```
See [Getting started](https://centia.io/docs/start) for more details.

## Prerequisites
- Docker Desktop or Docker Engine + Docker Compose v2
- Npm and Node.js for the CLI

## Quick start
1. Clone this repository
2. (Optional) Review and adjust environment variables in `conn.env`
3. Build and start the stack:
   - Development (build from local Dockerfile):
     - `docker compose up --build -d`
4. Wait for builds to complete (first run can take several minutes)
5. Access services:
   - Web (FrankenPHP/Caddy → app): http://localhost:81/
   - Event (WebSocket service): ws://localhost:82/
   - Postgres/PostGIS: localhost:5433 (forwarded to container 5432)

To stop: `docker compose down`

## Services overview
Defined in `docker-compose.yml`:
- centia-io-http
  - Builds target `http` from `Dockerfile`
  - Exposes port 81 → 80 in container
  - Loads env from `conn.env`
  - Depends on `postgres`
- centia-io-event
  - Builds target `event` from `Dockerfile`
  - WebSocket service exposed at ws://localhost:82 (host) → 80 (container)
  - Loads env from `conn.env`
  - Depends on `postgres`
- postgres
  - Image: `postgis/postgis:16-3.4`
  - Port 5433 → 5432
  - Env from `conn.env`
- redis
  - Image: `redis:6.2.6`
  - Internal network only

## Configuration
- Environment variables: `conn.env`
  - POSTGRES_HOST=postgres
  - POSTGRES_DB=mydb
  - POSTGRES_USER=mydb
  - POSTGRES_PORT=5432
  - POSTGRES_PASSWORD=1234
  - POSTGRES_PGBOUNCER=false
- Web server: `CaddyFile` (used by FrankenPHP in the `http` service)
- App config overrides: `conf/App.php`, `conf/Connection.php` are copied into the image during build

If you change `conn.env`, `conf/App.php` or `conf/Connection.php` re-create containers: 
`docker compose up -d` (add `--build` if Dockerfile or conf changes).

## Data persistence
By default, Postgres container storage is ephemeral. 
To persist data across `down`/recreate, uncomment the volume in `docker-compose.yml` under `postgres`:

```
  postgres:
    ...
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

After enabling, run `docker compose up -d` again.

## Common commands
- Build and start: `docker compose up --build -d`
- View logs: `docker compose logs -f --tail=100`
- Rebuild a single service: `docker compose build centia-io-http && docker compose up -d centia-io-http`
- Stop and remove: `docker compose down`
- Clean images (careful): `docker image prune -f`

## Troubleshooting
- First build is slow: it compiles native tools and Node modules. Subsequent builds are cached.
- Port conflicts:
  - Change `81:80` (HTTP) or `5433:5432` (Postgres) in `docker-compose.yml` if those host ports are in use.
- Database connection issues:
  - Confirm `POSTGRES_*` values in `conn.env`.
  - `docker compose ps` to see container health/status.
  - `docker compose logs postgres` to inspect database logs.
- Rebuild after changing app config or PHP settings: `docker compose up --build -d`.

# Centia.io Database Install System

Below explains how to use the Centia.io database installer at `http://localhost:81/install/`. It helps you:

- Verify the environment and list available PostgreSQL databases.
- Install required PostGIS extensions and the Centia.io `settings` schema into a selected database.
    - The settings schema is the only required schema for Centia.io to work. The installer doesn't change anything else in the database.
- Create the global `mapcentia` user database (if missing) and run its migrations.
- Elevate PostgreSQL credentials when necessary (insufficient privileges or connection failures).
- Create the owner user for a newly prepared database.

## Overview
The database install system lets you set up Centia.io on the PostgreSQL/PostGIS cluster. 
It performs the following:

- Checks that your server environment is ready (PHP and writable directories).
- For each non-system database, detects whether PostGIS and the `settings` schema are present.
- Allows you to initialize databases by creating PostGIS extensions and the settings schema.
- Runs a set of post-install SQL scripts needed by Centia.io. The first and last scripts are critical and must succeed (re-run is supported).
- After a successful prepare, prompts you to create the owner user for that database.
- After a successful user database creation, prompts yoor to change the ownership of the prepare database and its schema.
- Ensures the global `mapcentia` database exists and is migrated (stores Centia.io users and related metadata).


## Configuration and credentials
The installer uses connection parameters from environment variables (preferred) or
`app/conf/Connection.php` as a fallback. Environment variables:

- `POSTGRES_HOST` (e.g., `postgres`)
- `POSTGRES_DB` (default: `postgres`)
- `POSTGRES_USER` (e.g., `centia`)
- `POSTGRES_PORT` (default: `5432`)
- `POSTGRES_PASSWORD`
- `POSTGRES_PGBOUNCER` (default: `false`)

If the configured credentials lack privileges to create extensions, schemas, or databases,
the installer will show a form where you can enter elevated PostgreSQL credentials
(typically a superuser or a role with the required rights).
Your inputs are used only for the current operation and page reload.


## Pages and workflow
### 1) Index (overview):
Open in your browser: `http://localhost:81/install`

What it does:
- Displays PHP mode (FrankenPHP).
- Checks write access to `app/tmp`.
- Lists PostgreSQL databases and, for each non-system DB, indicates:
    - PostGIS: OK / Missing
    - Centia.io settings schema: OK / Missing
- If `mapcentia` database is missing, shows a warning with a button to create it (`http://localhost:81/userdatabase.php`).
- For databases missing requirements, shows an “Install” action that links to `http://localhost:81/prepare.php?db=<name>`.

System databases that are ignored by the prepare action include: `template0`, `template1`, `postgres`, `postgis_template`, `mapcentia`, `rdsadmin`.


### 2) Prepare a database for Centia.io: `http://localhost:81/install/prepare.php?db=<yourdb>`
Use this page to initialize a specific database for Centia.io.

Steps performed:
1) Connect to the selected database using the configured credentials. If connection fails, an elevation form is displayed to retry with different credentials.
2) Create PostGIS extensions (uses `CREATE EXTENSION postgis_raster CASCADE`).
    - If insufficient privileges (SQLSTATE `42501`), you will be prompted for elevated credentials.
3) Create the Centia.io settings schema.
    - Duplicate schema (SQLSTATE `42P06`) is treated as already installed and not a fatal error.
    - Insufficient privileges (SQLSTATE `42501`) prompts for elevated credentials.
4) Run post-install SQL scripts. For each script the page shows a badge:
    - OK badges are green; the first and last scripts are highlighted in blue on success.
    - SKIP badges are grey (or red for the first/last script when they fail).
    - The first and last scripts are critical. If either fails, the page shows a red alert and a “Re-run scripts” button to retry (reloads the page). It may take a couple of re-runs.
5) On overall success (first and last scripts are OK), a green success message appears and you are prompted to create the owner user for this database:
    - Provide an email and password.
    - The user’s `name` is set to the database name.
    - This creates the owner (super) user entry within Centia.io.
6) On user creation success, you are prompted to change ownership of the prepared database to the created user.

You can always return to the overview with the “Back to overview” button.


### 3) Create the global user database: `http://localhost:81/install/userdatabase.php`
This page ensures the global `mapcentia` database exists and applies migrations.

Steps performed:
1) Connect to the cluster (default database).
    - If connection fails, an elevation form is shown.
2) Create `mapcentia` if missing.
    - Duplicate database (SQLSTATE `42P04`) is treated as already existing.
    - Insufficient privileges (SQLSTATE `42501`) triggers the elevation prompt.
3) Connect to `mapcentia`.
    - Connection failure (SQLSTATE `08006`) triggers the elevation prompt.
4) Ensure the `users` table exists.
5) Run Centia.io migrations for the `mapcentia` database.
6) Finish with a success message and a link back to the overview.

Note: For `userdatabase.php` there is no special first/last script requirement.


## Handled error codes and elevation prompts
The installer inspects exception codes/messages and reacts to specific SQLSTATEs:
- `42501` insufficient_privilege: Shows an elevation form to provide higher-privileged PostgreSQL credentials.
- `42P06` duplicate_schema: Treated as a non-fatal “already exists” condition during schema creation.
- `42P04` duplicate_database: Treated as a non-fatal “already exists” condition when creating `mapcentia`.
- `08006` connection_failure: When trying to connect to `mapcentia`, prompts for credentials to retry.


## Typical usage scenarios
- Fresh setup:
    1) Visit `http://localhost:81/install/index.php` and verify environment checks.
    2) If prompted, click “Create database” to create `mapcentia` and run its migrations.
    3) For each data database you want to enable for Centia.io, click “Install” to open `http://localhost:81/prepare.php?db=<name>` and follow the steps.
    4) After a successful prepare, create the owner user when prompted.
    5) After a successful user creation, change the ownership of the prepared database to the created user. 


## Troubleshooting
- I get insufficient privileges (SQLSTATE 42501):
    - Provide a PostgreSQL superuser or a role that can create extensions, schemas, and (for `userdatabase.php`) databases.

- The first/last post-install scripts fail in `prepare.php`:
    - Use the “Re-run scripts” button. It can take a couple of re-runs depending on ordering or dependencies.
    - Check PostgreSQL logs for the exact failing SQL.

- Connection to `mapcentia` fails (SQLSTATE 08006):
    - Ensure the DB exists and is network-accessible. Provide elevated credentials if required.

## Security notes
- Only provide elevated (superuser) credentials when necessary and in a secure environment.
- The installer uses provided credentials for the current page action; do not reuse privileged credentials for routine app operations.
- Once installation is done, consider restricting access to the `/install/` directory or removing it from publicly accessible locations.
