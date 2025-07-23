CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    email TEXT,
    role TEXT NOT NULL DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE viewers (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT UNIQUE,
    description TEXT,
    owner_id INTEGER REFERENCES users(id),
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE layer_services (
    id SERIAL PRIMARY KEY,
    name TEXT,
    type TEXT NOT NULL, -- e.g. wms, wfs, arcgis-rest
    url TEXT NOT NULL,
    version TEXT,
    crs TEXT,
    auth_type TEXT DEFAULT 'none', -- e.g. none, token, basic
    last_checked TIMESTAMP
);

CREATE TABLE layers (
    id SERIAL PRIMARY KEY,
    viewer_id INTEGER REFERENCES viewers(id),
    service_id INTEGER REFERENCES layer_services(id),
    layer_name TEXT NOT NULL,
    title TEXT,
    min_zoom INTEGER,
    max_zoom INTEGER,
    bbox JSONB, -- or use PostGIS geometry if enabled
    style_mode TEXT DEFAULT 'simple',
    render_strategy TEXT,
    layer_params JSONB,
    visible BOOLEAN DEFAULT TRUE,
    sort_order INTEGER
);

CREATE TABLE viewer_permissions (
    id SERIAL PRIMARY KEY,
    viewer_id INTEGER REFERENCES viewers(id),
    user_id INTEGER REFERENCES users(id),
    access_level TEXT DEFAULT 'read' -- read, edit, owner
);

