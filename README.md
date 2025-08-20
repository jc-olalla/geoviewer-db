# GeoViewer Database

This repository contains the database schema per tenant/organization, initialization scripts, and sample data for the GeoViewer project. It is modular, extensible, and designed to work as part of the full GeoViewer stack.

### 🛠️ Setup

1. **Clone the repository**

```bash
git clone https://github.com/jc-olalla/geoviewer-db.git
cd geoviewer-db
```

2. **Start the database**

```bash
# Fix permissions
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker $USER
newgrp docker
docker run --rm hello-world

# 0) (optional) stop any app/migrator containers using the DB
docker rm -f pg-catalog || true

# 1) start a fresh Postgres 16
#    NOTE: we also mount the CSV so COPY ... FROM works later (see seed note below)
docker run --name pg-catalog \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  -v "$PWD/sql/sample_layers.csv":/docker-entrypoint-initdb.d/sample_layers.csv:ro \
  -d postgres:16

# Build docker image
docker build -f Dockerfile.migrator -t catalog-migrator:latest .

# If running locally, start Postgres as a container, listening on host port 5432
#docker run --name pg-catalog -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:16

# Sanity check: list DBs (should connect)
#psql "postgresql://postgres:postgres@localhost:5432/postgres" -c "\l"

# Create tenant DB(s) + apply schema (using migrator)
docker run --rm \
  --add-host=host.docker.internal:host-gateway \
  -v "$(pwd)/tenants.yaml:/work/tenants.yaml:ro" \
  catalog-migrator:latest \
  bootstrap --tenants /work/tenants.yaml \
  --admin-dsn postgresql://postgres:postgres@host.docker.internal:5432/postgres

# Seed
docker run --rm \
  --add-host=host.docker.internal:host-gateway \
  -v "$PWD/tenants.yaml:/work/tenants.yaml:ro" \
  catalog-migrator:latest \
  seed --tenants /work/tenants.yaml

# print env for the api
TENANT_DSN_MAP=$(docker run --rm \
  -v "$PWD/tenants.yaml:/work/tenants.yaml:ro" \
  catalog-migrator:latest \
  print-env --tenants /work/tenants.yaml)
echo "$TENANT_DSN_MAP"


```



---

## 🐚 Accessing the Database

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
