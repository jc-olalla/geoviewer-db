-- sample_data.sql

INSERT INTO users (username, password_hash, role)
VALUES
  ('admin', 'fake_hash', 'admin'),
  ('user1', 'fake_hash2', 'user');

INSERT INTO viewers (name, slug, owner_id, is_public)
VALUES
  ('Main Viewer', 'main-viewer', 1, TRUE),
  ('Private Viewer', 'private-viewer', 2, FALSE);

-- Load layers from CSV
-- Make sure sample_layers.csv is placed in /docker-entrypoint-initdb.d/

COPY layers(viewer_id, type, name, title, url, layer_name, version, crs, format, tiled, opacity, visible, sort_order, layer_params)
FROM '/docker-entrypoint-initdb.d/sample_layers.csv'
WITH (FORMAT csv, HEADER true);

-- Optional: You can add manual inserts here
--INSERT INTO layers (
--  viewer_id, type, name, title, url, layer_name,
--  version, crs, format, tiled, opacity, visible,
--  sort_order, layer_params
--) VALUES (
--  1, 'wms', 'bag_pand', 'BAG Pand',
--  'https://service.pdok.nl/lv/bag/wms/v2_0',
--  'pand',
--  '1.1.1', 'EPSG:3857', 'image/png', true, 0.8, true,
--  1,
--  '{"TRANSPARENT": "true"}'
--);
--
--INSERT INTO layers (
--  viewer_id, type, name, title, url, layer_name,
--  version, crs, format, opacity, visible, sort_order
--) VALUES (
--  1, 'wfs', 'bag_pand_wfs', 'BAG Pand (WFS)',
--  'https://service.pdok.nl/lv/bag/wfs/v2_0',
--  'pand',
--  '2.0.0', 'EPSG:28992', 'application/json',
--  1.0, false, 2
--);


INSERT INTO viewer_permissions (viewer_id, user_id, access_level)
VALUES
  (2, 2, 'read');

