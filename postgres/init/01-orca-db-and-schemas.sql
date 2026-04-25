-- Bootstrap ORCA's orca_public schema on first start.
--
-- Runs once when the Postgres data volume is empty (Postgres image
-- behaviour for /docker-entrypoint-initdb.d/*.sql files). The script
-- is executed inside the database named by POSTGRES_DB (set in
-- .env.postgres to "orca"), which the image creates automatically
-- before running init scripts.
--
-- IMPORTANT: The AUTHORIZATION identifier below ("orcaadmin") must
-- match POSTGRES_USER in .env.postgres. The healthcheck in
-- docker-compose.yml also references "orcaadmin" and "orca". Keep
-- all three in sync if you ever rename them.
--
-- ORCA's Prisma config expects schema "orca_public". The "orca_test"
-- schema used by ORCA's local unit tests is intentionally NOT
-- created here (the deployed PoC does not run those tests).

CREATE SCHEMA IF NOT EXISTS orca_public AUTHORIZATION orcaadmin;
