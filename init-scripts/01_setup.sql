-- setup.sql

-- Connect to default 'postgres' database
\c postgres

-- Let Docker handle user creation via .env
-- Ensure the database is created if not already
DO $$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_database WHERE datname = 'gis_viewer'
   ) THEN
      CREATE DATABASE gis_viewer OWNER gis_admin;
   END IF;
END
$$;

-- Grant privileges (safe even if database already exists)
GRANT ALL PRIVILEGES ON DATABASE gis_viewer TO gis_admin;

