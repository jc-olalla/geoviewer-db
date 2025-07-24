# GeoViewer Database

This repository contains the database schema, initialization scripts, and sample data for the GeoViewer project. It is modular, extensible, and designed to work as part of the full GeoViewer stack.

---

## 📦 Stack

- **PostgreSQL 16**
- Optional support for **PostGIS**
- Init system based on **SQL + CSV**

---

## Getting Started

### Prerequisites

- [Docker](https://www.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- (Optional) [psql CLI](https://www.postgresql.org/docs/current/app-psql.html)

---

### 🛠️ Setup

1. **Clone the repository**

```bash
git clone https://github.com/jc-olalla/geoviewer-db.git
cd geoviewer-db
```

2. **Start the database**

```bash
sudo docker-compose up --build
```

This will:

- Launch a PostgreSQL container
- Initialize the `geoviewer` database
- Run the SQL scripts from `init-scripts/`
- Load sample layers from `sample_layers.csv` (if present)

---

## Rebuilding or Resetting

If the container name is already taken, you might see:

```
Cannot create container for service db: Conflict. The container name "/geoviewer_db" is already in use...
```

To fix it:

```bash
sudo docker rm geoviewer_db
```

Or remove everything and rebuild from scratch:

```bash
sudo docker-compose down -v
sudo docker-compose up --build
```

---

## Accessing the Database

To connect using `psql`:

```bash
psql -h localhost -U geoadmin -d geoviewer
```

When prompted for a password, enter the value defined in your `.env` file (default is `postgres`).

Example `.env`:

```env
POSTGRES_DB=geoviewer
POSTGRES_USER=geoadmin
POSTGRES_PASSWORD=postgres
```

---

## 📁 File Structure

```bash
geoviewer-db/
├── init-scripts/
│   ├── 01_setup.sql            # Create DB + admin user
│   ├── 02_viewer_schema.sql    # Core schema (users, viewers, layers)
│   └── 03_sample_data.sql      # Sample data + layer loading
├── sample_layers.csv           # Optional CSV with layer definitions
├── .env                        # DB name, user, password
├── docker-compose.yml          # PostgreSQL service definition
└── README.md                   # This file
```

---

## 🧪 Adding Layers

You have two options:

### ✅ Option A: CSV-based input

Edit `sample_layers.csv` with new layer records. Example:

```csv
viewer_id,type,name,title,url,layer_name,version,crs,format,tiled,opacity,visible,sort_order,layer_params
1,wms,bag_pand,BAG Pand,https://service.pdok.nl/lv/bag/wms/v2_0,pand,1.1.1,EPSG:3857,image/png,true,1,true,1,"{""TRANSPARENT"":""true""}"
```

This will be automatically loaded by `03_sample_data.sql`:

```sql
COPY layers(viewer_id, type, name, title, url, layer_name, version, crs, format, tiled, opacity, visible, sort_order, layer_params)
FROM '/docker-entrypoint-initdb.d/sample_layers.csv'
WITH (FORMAT csv, HEADER true);
```

### ✅ Option B: Manual INSERT

You can also directly edit `03_sample_data.sql`:

```sql
INSERT INTO layers (
  viewer_id, type, name, title, url, layer_name,
  version, crs, format, tiled, opacity, visible,
  sort_order, layer_params
) VALUES (
  1, 'wms', 'bag_pand', 'BAG Pand',
  'https://service.pdok.nl/lv/bag/wms/v2_0',
  'pand',
  '1.1.1', 'EPSG:3857', 'image/png', true, 0.8, true,
  1,
  '{"TRANSPARENT": "true"}'
);
```

---

## ✅ Next Steps

After the database is running, connect it to:

- [GeoViewer API](https://github.com/your-org/geoviewer-api)
- [GeoViewer App](https://github.com/your-org/geoviewer-app)
