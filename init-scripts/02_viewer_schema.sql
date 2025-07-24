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

CREATE TABLE layers (
    id SERIAL PRIMARY KEY,
    viewer_id INTEGER REFERENCES viewers(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('wms', 'wfs', 'wcs', 'file', 'xyz', 'vector')),
    name TEXT NOT NULL, -- internal name
    title TEXT, -- display title
    url TEXT, -- endpoint (null for local files)
    layer_name TEXT, -- e.g. 'pand' in WMS
    version TEXT, -- e.g. '1.1.1'
    crs TEXT DEFAULT 'EPSG:3857',
    style TEXT,
    format TEXT,
    tiled BOOLEAN,
    opacity REAL DEFAULT 1.0 CHECK (opacity >= 0 AND opacity <= 1),
    visible BOOLEAN DEFAULT TRUE,
    min_zoom INTEGER,
    max_zoom INTEGER,
    sort_order INTEGER,
    layer_params JSONB, -- custom parameters, overrides default ones
    extra_config JSONB, -- viewer-specific overrides (e.g. popup config)
    bbox JSONB, -- viewer-specific overrides (e.g. popup config)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE viewer_permissions (
    id SERIAL PRIMARY KEY,
    viewer_id INTEGER REFERENCES viewers(id),
    user_id INTEGER REFERENCES users(id),
    access_level TEXT DEFAULT 'read' -- read, edit, owner
);

