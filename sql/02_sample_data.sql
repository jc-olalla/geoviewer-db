-- 02_sample_data.sql
-- Idempotent seed for 01_viewer_schema.sql

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
INSERT INTO viewers (name, slug, owner_id, is_public, description)
SELECT 'Main Viewer', 'main-viewer',
       (SELECT id FROM users WHERE username = 'admin'),
       TRUE,
       'Public demo map'
WHERE NOT EXISTS (SELECT 1 FROM viewers WHERE slug = 'main-viewer');

INSERT INTO viewers (name, slug, owner_id, is_public, description)
SELECT 'Private Viewer', 'private-viewer',
       (SELECT id FROM users WHERE username = 'user1'),
       FALSE,
       'Private workspace for user1'
WHERE NOT EXISTS (SELECT 1 FROM viewers WHERE slug = 'private-viewer');

-- -------------------------------------------------------------------
-- Viewer permissions (reflect ownership + an extra grant)
-- -------------------------------------------------------------------
-- Admin is owner of main-viewer
WITH v AS (
  SELECT id AS viewer_id FROM viewers WHERE slug = 'main-viewer'
), u AS (
  SELECT id AS user_id FROM users WHERE username = 'admin'
)
INSERT INTO viewer_permissions (viewer_id, user_id, access_level)
SELECT v.viewer_id, u.user_id, 'owner'
FROM v, u
WHERE NOT EXISTS (
  SELECT 1 FROM viewer_permissions vp
  WHERE vp.viewer_id = v.viewer_id AND vp.user_id = u.user_id
);

-- user1 is owner of private-viewer
WITH v AS (
  SELECT id AS viewer_id FROM viewers WHERE slug = 'private-viewer'
), u AS (
  SELECT id AS user_id FROM users WHERE username = 'user1'
)
INSERT INTO viewer_permissions (viewer_id, user_id, access_level)
SELECT v.viewer_id, u.user_id, 'owner'
FROM v, u
WHERE NOT EXISTS (
  SELECT 1 FROM viewer_permissions vp
  WHERE vp.viewer_id = v.viewer_id AND vp.user_id = u.user_id
);

-- (Optional example) Grant 'read' on private-viewer to admin as well
WITH v AS (
  SELECT id AS viewer_id FROM viewers WHERE slug = 'private-viewer'
), u AS (
  SELECT id AS user_id FROM users WHERE username = 'admin'
)
INSERT INTO viewer_permissions (viewer_id, user_id, access_level)
SELECT v.viewer_id, u.user_id, 'read'
FROM v, u
WHERE NOT EXISTS (
  SELECT 1 FROM viewer_permissions vp
  WHERE vp.viewer_id = v.viewer_id AND vp.user_id = u.user_id
);

-- -------------------------------------------------------------------
-- Layers (global catalog; no viewer_id column here)
-- -------------------------------------------------------------------

-- BAG Pand (WMS)
INSERT INTO layers (
  type, name, title, url, layer_name, version, crs, format,
  tiled, opacity, visible, sort_order, layer_params
)
SELECT 'wms', 'bag_pand', 'BAG Pand',
       'https://service.pdok.nl/lv/bag/wms/v2_0', 'pand', '1.1.1',
       'EPSG:3857', 'image/png',
       TRUE, 0.8, TRUE, 1, '{"TRANSPARENT":"true"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM layers l WHERE l.name = 'bag_pand');

-- BAG Pand (WFS)
INSERT INTO layers (
  type, name, title, url, layer_name, version, crs, format,
  tiled, opacity, visible, sort_order, layer_params
)
SELECT 'wfs', 'bag_pand_wfs', 'BAG Pand (WFS)',
       'https://service.pdok.nl/lv/bag/wfs/v2_0', 'pand', '2.0.0',
       'EPSG:28992', 'application/json',
       FALSE, 1.0, FALSE, 2, '{}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM layers l WHERE l.name = 'bag_pand_wfs');

-- Mogelijk Portiekwoningen (Supabase REST)
INSERT INTO layers (
  type, name, title, url, layer_name, version, crs, format,
  tiled, opacity, visible, sort_order, layer_params, extra_config
)
SELECT 'supabase_rest', 'mogelijk_portiekwoningen', 'Mogelijk Portiekwoningen',
       'https://dctmgvivsthofjcmejsd.supabase.co/rest/v1/buildings_geojson', 'buildings_geojson', 'v1',
       'EPSG:3857', 'application/json',
       FALSE, 1.0, FALSE, 3, '{}'::jsonb, '{"headers":{"apikey":"<set-in-app-or-env>"}}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM layers l WHERE l.name = 'mogelijk_portiekwoningen');

-- -------------------------------------------------------------------
-- Layer ↔ Viewer relationship & per-viewer options
-- -------------------------------------------------------------------
-- Put BAG WMS + Supabase layer into Main Viewer
WITH v AS (SELECT id AS viewer_id FROM viewers WHERE slug = 'main-viewer'),
     l AS (
       SELECT id, name FROM layers WHERE name IN ('bag_pand','mogelijk_portiekwoningen')
     )
INSERT INTO layer_permissions (viewer_id, layer_id, access_level, default_visible, can_toggle, sort_order_override)
SELECT v.viewer_id, l.id,
       'read',
       CASE WHEN l.name = 'bag_pand' THEN TRUE ELSE FALSE END,
       TRUE,
       CASE WHEN l.name = 'bag_pand' THEN 1 ELSE 3 END
FROM v, l
WHERE NOT EXISTS (
  SELECT 1 FROM layer_permissions lp
  WHERE lp.viewer_id = v.viewer_id AND lp.layer_id = l.id
);

-- Put BAG WFS into Private Viewer and keep it hidden by default
WITH v AS (SELECT id AS viewer_id FROM viewers WHERE slug = 'private-viewer'),
     l AS (SELECT id FROM layers WHERE name = 'bag_pand_wfs')
INSERT INTO layer_permissions (viewer_id, layer_id, access_level, default_visible, can_toggle, sort_order_override)
SELECT v.viewer_id, l.id, 'read', FALSE, TRUE, 2
FROM v, l
WHERE NOT EXISTS (
  SELECT 1 FROM layer_permissions lp
  WHERE lp.viewer_id = v.viewer_id AND lp.layer_id = l.id
);

-- -------------------------------------------------------------------
-- Styles (simple example) and Layer → Style binding
-- -------------------------------------------------------------------
-- Create a reusable simple style
INSERT INTO styles (name, json, created_by)
SELECT 'Simple Blue Fill',
       '{
          "version": 1,
          "rules": [{
            "name": "default",
            "symbolizers": [{
              "kind": "Fill",
              "color": "#4C78A8",
              "opacity": 0.6,
              "outlineColor": "#1F2D3D",
              "outlineWidth": 1
            }]
          }]
        }'::jsonb,
       (SELECT id FROM users WHERE username = 'admin')
WHERE NOT EXISTS (SELECT 1 FROM styles s WHERE lower(s.name) = lower('Simple Blue Fill'));

-- Bind the style to BAG Pand (WFS) (vector-ish response)
WITH st AS (SELECT id AS style_id FROM styles WHERE name = 'Simple Blue Fill'),
     ly AS (SELECT id AS layer_id FROM layers WHERE name = 'bag_pand_wfs')
INSERT INTO layer_styles (layer_id, style_id, enabled)
SELECT ly.layer_id, st.style_id, TRUE
FROM st, ly
WHERE NOT EXISTS (
  SELECT 1 FROM layer_styles ls WHERE ls.layer_id = ly.layer_id
);

-- -------------------------------------------------------------------
-- (Optional) Additional friendly grants
-- -------------------------------------------------------------------
-- Give user1 read access to main-viewer
WITH v AS (
  SELECT id AS viewer_id FROM viewers WHERE slug = 'main-viewer'
), u AS (
  SELECT id AS user_id FROM users WHERE username = 'user1'
)
INSERT INTO viewer_permissions (viewer_id, user_id, access_level)
SELECT v.viewer_id, u.user_id, 'read'
FROM v, u
WHERE NOT EXISTS (
  SELECT 1 FROM viewer_permissions vp
  WHERE vp.viewer_id = v.viewer_id AND vp.user_id = u.user_id
);

