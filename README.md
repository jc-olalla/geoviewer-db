# GeoViewer Database

Provision a **schema-per-tenant** PostgreSQL database for GeoViewer on **any infrastructure** (Supabase, managed Postgres, a company warehouse, or a local laptop for testing). Provisioning is executed by **GitHub Actions** using the Dockerized provisioner in this repo—no manual Docker commands required.

- **Provisioner:** `Dockerfile.migrator` + `scripts/catalogctl.py`  
- **Schema SQL:** `sql/01_viewer_schema.sql` (+ optional `sql/02_sample_data.sql`)  
- **Tenants manifest:** `tenants.yaml`  
- **Workflow:** `.github/workflows/main.yml` (builds the image and runs it)

---

## How it works

Running the workflow builds the provisioner image and executes it on a runner. The container reads `tenants.yaml`, connects to the **target Postgres** via a `DB_URL` secret, creates shared objects, and creates **one schema per tenant**. The container exits; the database keeps the changes.

- **Public targets** (e.g., Supabase): run on a GitHub-hosted runner.  
- **Private targets** (e.g., a VPC-only warehouse or your laptop): run on a **self-hosted runner** that can reach that database.

---

## One-time setup

1. **Clone**
   ```bash
   git clone https://github.com/jc-olalla/geoviewer-db.git
   cd geoviewer-db
   ```

2. **(If you need private access) Register a self-hosted runner**
   - Repo → **Settings → Actions → Runners → New self-hosted runner**.  
   - Follow the on-screen commands to `./config.sh` and start with `./run.sh`  
     (or install as a service: `./svc.sh install && ./svc.sh start`).  
   - Ensure it shows **Online** under **Settings → Actions → Runners**.

> You can skip step 2 for public targets like Supabase; GitHub’s hosted runners will work.

---

## Add a target (Environment per destination)

For **each** destination you want to provision (e.g., `supabase`, `warehouse`, `linux_laptop`):

1. **Create an Environment**
   - Repo → **Settings → Environments → New environment**  
   - Name it after the target (examples: `supabase`, `warehouse`, `linux_laptop`).

2. **Add secrets (minimum: `DB_URL`)**
   - `DB_URL` = the full Postgres connection string for that target.

   Examples:
   - **Supabase**  
     `postgresql://USER:PASSWORD@HOST:PORT/postgres?sslmode=require`
   - **Company warehouse (private address)**  
     `postgresql://USER:PASSWORD@db.internal.company:5432/yourdb`
   - **Laptop (testing)**  
     `postgresql://postgres:postgres@host.docker.internal:5432/postgres?sslmode=disable`  
     *(The workflow starts the container with the proper host mapping so this name reaches your host.)*

3. **(Private targets) Bind the Environment to a self-hosted runner**
   - If your DB isn’t publicly reachable, ensure the Environment can use your self-hosted runner (runner must be Online and able to reach the DB host/port).

> Keep the secret name exactly **`DB_URL`** across all Environments so the workflow stays generic.

---

## Run provisioning

1. Go to **Actions → Catalog Provisioner → Run workflow**.  
2. Inputs:
   - **`target_environment`**: the Environment name (e.g., `supabase`, `warehouse`, `linux_laptop`).  
   - **`run_smoke_test`**: `true` recommended (quick check against an ephemeral Postgres before touching your target).  
3. Click **Run workflow**.  
   - For public targets, the job runs on a GitHub-hosted runner.  
   - For private targets, it runs on your self-hosted runner.

When the run finishes successfully, your database will have one schema per tenant listed in `tenants.yaml`.

---

## Verify

Use any Postgres client with the same connection as `DB_URL` (adjust host if you’re checking locally). For example:

```bash
psql "postgresql://USER:PASSWORD@HOST:PORT/DBNAME" -c "SELECT nspname FROM pg_namespace
 WHERE nspname NOT LIKE 'pg_%' AND nspname <> 'information_schema'
 ORDER BY 1;"
```

You should see the tenant schemas from `tenants.yaml` (e.g., `brandweer`). To list tables for a tenant: `\dt tenant_name.*`

---

## Seeding (optional)

The workflow focuses on provisioning. If you later enable seeding with `sql/02_sample_data.sql`, add a `seed` step or flag in the workflow and ensure any external files (e.g., CSV) are accessible in that context.

---

## Troubleshooting

- **Job ran on the wrong machine**  
  In the job logs, “Runner Image: ubuntu-24.04” = hosted VM; a self-hosted runner shows your custom name. Ensure the `provision` job uses `runs-on: [self-hosted, Linux, X64]` and your runner is Online.

- **Cannot connect to DB**  
  Verify `DB_URL` is correct for the target and the runner can reach `HOST:PORT`. For laptop testing, ensure Postgres is running on port 5432.

- **`host.docker.internal` not found (Linux)**  
  The workflow’s `docker run` adds the proper host mapping for private targets; keep the provided YAML as-is.

---

## Repo layout

```
.
├── Dockerfile.migrator
├── README.md
├── scripts/
│   └── catalogctl.py
├── sql/
│   ├── 01_viewer_schema.sql
│   ├── 02_sample_data.sql
│   └── sample_layers.csv
└── tenants.yaml
```

## ✅ Next Steps

After the database is running, connect it to:

- [GeoViewer API](https://github.com/your-org/geoviewer-api)
- [GeoViewer App](https://github.com/your-org/geoviewer-app)
