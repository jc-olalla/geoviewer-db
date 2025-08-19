#!/usr/bin/env python3
"""
Catalog bootstrap/migrate helper.

Commands:
  - bootstrap: create DBs (optional) and apply schema SQL to each tenant
  - seed:      apply seed SQL to each tenant
  - print-env: print TENANT_DSN_MAP JSON for the API

Requires: pip install psycopg[binary] pyyaml
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import sys
from typing import List

import yaml

import psycopg

ROOT = Path(__file__).resolve().parents[1]
SQL_SCHEMA = ROOT / "sql" / "01_viewer_schema.sql"
SQL_SEED = ROOT / "sql" / "02_sample_data.sql"


def load_tenants(path: Path) -> List[dict]:
    data = yaml.safe_load(path.read_text())
    tenants = data.get("tenants") or []
    if not isinstance(tenants, list):
        raise SystemExit("Invalid tenants.yaml: 'tenants' must be a list")
    out: List[dict] = []
    for t in tenants:
        slug = str(t["slug"]).lower()
        out.append(
            {
                "slug": slug,
                "dbname": t.get("dbname") or f"{slug}_catalog",
                "dsn": t["dsn"],
                "create": bool(t.get("create", False)),
            }
        )
    return out


def create_db_if_needed(admin_dsn: str, dbname: str) -> None:
    # Connect to admin DB (usually 'postgres') to create databases
    with psycopg.connect(admin_dsn, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM pg_database WHERE datname=%s", (dbname,))
            exists = cur.fetchone() is not None
            if not exists:
                cur.execute(f'CREATE DATABASE "{dbname}"')
                print(f"  created {dbname}")
            else:
                print(f"  exists {dbname}")


def run_sql_file(dsn: str, sql_file: Path) -> None:
    sql = sql_file.read_text()
    with psycopg.connect(dsn, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(sql)


def cmd_bootstrap(args) -> None:
    tenants = load_tenants(Path(args.tenants))
    if any(t["create"] for t in tenants) and not args.admin_dsn:
        sys.exit("bootstrap: --admin-dsn is required when any tenant has create: true")
    for t in tenants:
        print(f"== {t['slug']} ==")
        if t["create"]:
            create_db_if_needed(args.admin_dsn, t["dbname"])
        print("  -> apply schema")
        run_sql_file(t["dsn"], SQL_SCHEMA)
    print("Done.")


def cmd_seed(args) -> None:
    if not SQL_SEED.exists():
        sys.exit(f"seed file not found: {SQL_SEED}")
    tenants = load_tenants(Path(args.tenants))
    for t in tenants:
        print(f"== {t['slug']} (seed) ==")
        run_sql_file(t["dsn"], SQL_SEED)
    print("Done.")


def cmd_print_env(args) -> None:
    tenants = load_tenants(Path(args.tenants))
    mapping = {t["slug"]: t["dsn"] for t in tenants}
    print(json.dumps(mapping))


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    p1 = sub.add_parser("bootstrap", help="create DBs (optional) + apply schema")
    p1.add_argument("--tenants", required=True)
    p1.add_argument("--admin-dsn")
    p1.set_defaults(func=cmd_bootstrap)

    p2 = sub.add_parser("seed", help="apply seed SQL to each tenant DB")
    p2.add_argument("--tenants", required=True)
    p2.set_defaults(func=cmd_seed)

    p3 = sub.add_parser("print-env", help="print TENANT_DSN_MAP JSON")
    p3.add_argument("--tenants", required=True)
    p3.set_defaults(func=cmd_print_env)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
