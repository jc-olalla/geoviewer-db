-- setup.sql
DROP DATABASE IF EXISTS gis_viewer;
DROP USER IF EXISTS gis_admin;

CREATE USER gis_admin WITH PASSWORD 'your_secure_password';
CREATE DATABASE gis_viewer OWNER gis_admin;
GRANT ALL PRIVILEGES ON DATABASE gis_viewer TO gis_admin;

