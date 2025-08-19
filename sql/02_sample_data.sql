-- 02_sample_data.sql

-- Ensure sample users exist (idempotent)
INSERT INTO users (username, password_hash, role, email, is_system, is_active)
SELECT 'admin', 'fake_hash', 'admin', 'admin@example.local', false, true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');

INSERT INTO users (username, password_hash, role, email, is_system, is_active)
SELECT 'user1', 'fake_hash2', 'user', 'user1@example.local', false, true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'user1');

-- Viewers owned by the right users (no hardcoded IDs)
INSERT INTO viewers (name, slug, owner_id, is_public)
SELECT 'Main Viewer', 'main-viewer',
       (SELECT id FROM users WHERE username = 'admin'),
       TRUE
WHERE NOT EXISTS (SELECT 1 FROM viewers WHERE slug = 'main-viewer');

INSERT INTO viewers (name, slug, owner_id, is_public)
SELECT 'Private Viewer', 'private-viewer',
       (SELECT id FROM users WHERE username = 'user1'),
       FALSE
WHERE NOT EXISTS (SELECT 1 FROM viewers WHERE slug = 'private-viewer');

-- Load layers from CSV
-- NOTE: This path is on the *server* (inside the Postgres container).
-- Mount the file there (e.g., -v "$PWD/sql/sample_layers.csv":/docker-entrypoint-initdb.d/sample_layers.csv:ro)
COPY layers(viewer_id, type, name, title, url, layer_name, version, crs, format, tiled, opacity, visible, sort_order, layer_params)
FROM '/docker-entrypoint-initdb.d/sample_layers.csv'
WITH (FORMAT csv, HEADER true);

-- Grant permissions (defines its own CTEs in the same statement)
WITH v_private AS (
  SELECT id AS viewer_id FROM viewers WHERE slug = 'private-viewer'
),
u_user1 AS (
  SELECT id AS user_id FROM users WHERE username = 'user1'
)
INSERT INTO viewer_permissions (viewer_id, user_id, access_level)
SELECT v.viewer_id, u.user_id, 'read'
FROM v_private v, u_user1 u
WHERE NOT EXISTS (
  SELECT 1
  FROM viewer_permissions vp
  WHERE vp.viewer_id = v.viewer_id AND vp.user_id = u.user_id
);

