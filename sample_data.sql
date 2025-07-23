-- sample_data.sql

INSERT INTO users (username, password_hash, role)
VALUES
  ('admin', 'fake_hash', 'admin'),
  ('user1', 'fake_hash2', 'user');

INSERT INTO viewers (name, slug, owner_id, is_public)
VALUES
  ('Main Viewer', 'main-viewer', 1, TRUE),
  ('Private Viewer', 'private-viewer', 2, FALSE);

INSERT INTO layer_services (name, type, url)
VALUES
  ('OSM WMS', 'wms', 'https://example.com/wms');

INSERT INTO layers (viewer_id, service_id, layer_name, title)
VALUES
  (1, 1, 'roads', 'Road Network'),
  (2, 1, 'buildings', 'Building Footprints');

INSERT INTO viewer_permissions (viewer_id, user_id, access_level)
VALUES
  (2, 2, 'read');

