-- 02_sample_data.sql
-- Idempotent seed 

-- -------------------------------------------------------------------
-- Users (create if missing)
-- -------------------------------------------------------------------
INSERT INTO users (username, password_hash, role, email, is_system, is_active)
SELECT 'admin', 'fake_hash', 'admin', 'admin@example.local', false, true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'admin');

INSERT INTO users (username, password_hash, role, email, is_system, is_active)
SELECT 'user1', 'fake_hash2', 'user', 'user1@example.local', false, true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = 'user1');

-- -------------------------------------------------------------------
-- Viewers (owned by the right users; no hardcoded IDs)
-- -------------------------------------------------------------------
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

-- -------------------------------------------------------------------
-- Layers 
-- -------------------------------------------------------------------

-- BAG Pand (WMS) in Main Viewer
INSERT INTO layers (
  viewer_id, type, name, title, url, layer_name, version, crs, format,
  tiled, opacity, visible, sort_order, layer_params
)
SELECT v.id, 'wms', 'bag_pand', 'BAG Pand',
       'https://service.pdok.nl/lv/bag/wms/v2_0', 'pand', '1.1.1',
       'EPSG:3857', 'image/png',
       TRUE, 0.8, TRUE, 1, '{"TRANSPARENT":"true"}'::jsonb
FROM viewers v
WHERE v.slug = 'main-viewer'
  AND NOT EXISTS (SELECT 1 FROM layers l WHERE l.name = 'bag_pand');

-- BAG Pand (WFS) in Private Viewer
INSERT INTO layers (
  viewer_id, type, name, title, url, layer_name, version, crs, format,
  tiled, opacity, visible, sort_order, layer_params
)
SELECT v.id, 'wfs', 'bag_pand_wfs', 'BAG Pand (WFS)',
       'https://service.pdok.nl/lv/bag/wfs/v2_0', 'pand', '2.0.0',
       'EPSG:28992', 'application/json',
       FALSE, 1.0, FALSE, 2, '{}'::jsonb
FROM viewers v
WHERE v.slug = 'private-viewer'
  AND NOT EXISTS (SELECT 1 FROM layers l WHERE l.name = 'bag_pand_wfs');

-- Mogelijk Portiekwoningen (Supabase REST) in Main Viewer
INSERT INTO layers (
  viewer_id, type, name, title, url, layer_name, version, crs, format,
  tiled, opacity, visible, sort_order, layer_params
)
SELECT v.id, 'supabase_rest', 'mogelijk_portiekwoningen', 'Mogeglijk Portiekwoningen',
       'https://dctmgvivsthofjcmejsd.supabase.co/rest/v1/buildings_geojson', 'dummy', 'v1',
       'EPSG:3857', 'application/json',
       FALSE, 1.0, FALSE, 2, '{}'::jsonb
FROM viewers v
WHERE v.slug = 'main-viewer'
  AND NOT EXISTS (SELECT 1 FROM layers l WHERE l.name = 'mogelijk_portiekwoningen');

-- -------------------------------------------------------------------
-- Viewer permissions (grant 'read' on the private viewer to user1)
-- -------------------------------------------------------------------
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
