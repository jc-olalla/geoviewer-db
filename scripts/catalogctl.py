#!/usr/bin/env python3
"""
GeoViewer catalog provisioner (single DB, schema-per-tenant).

Commands:
  - bootstrap: ensure tenant schema exists, then apply schema SQL
  - seed:      apply seed SQL
  - print-env: emit {slug: dsn} map (composed from --base-dsn)

Usage:
  python scripts/catalogctl.py bootstrap --tenants tenants.yaml --base-dsn "postgresql://.../postgres?sslmode=require"
  python scripts/catalogctl.py seed      --tenants tenants.yaml --base-dsn "postgresql://.../postgres?sslmode=require"
  python scripts/catalogctl.py print-env --tenants tenants.yaml --base-dsn "postgresql://.../postgres?sslmode=require"

Requires: psycopg[binary], pyyaml
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import sys
from typing import Dict, List
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

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
                "schema": (t.get("schema") or slug),
                "description": t.get("description"),
            }
        )
    return out


def compose_dsn(base_dsn: str, schema: str) -> str:
    """Append search_path to base_dsn via libpq 'options', properly URL-encoded."""
    pr = urlparse(base_dsn)
    if not pr.path or pr.path == "/":
        pr = pr._replace(path="/postgres")

    q = dict(parse_qsl(pr.query, keep_blank_values=True))
    # Include a space after -c; let urlencode encode space, '=' and ','.
    addition = f"-c search_path={schema},public"

    if "options" in q and q["options"]:
        # If options already present, append with a space; urlencode will encode spaces.
        q["options"] = f"{q['options']} {addition}"
    else:
        q["options"] = addition

    # IMPORTANT: don't mark '=' or space as safe; let them be percent-encoded
    pr = pr._replace(query=urlencode(q, safe=":-_."))
    return urlunparse(pr)


def run_sql_file(dsn: str, sql_file: Path) -> None:
    sql = sql_file.read_text()
    with psycopg.connect(dsn, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(sql)


def ensure_schema(dsn: str, schema: str) -> None:
    with psycopg.connect(dsn, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(
                f'CREATE SCHEMA IF NOT EXISTS "{schema}" AUTHORIZATION CURRENT_USER'
            )


def cmd_bootstrap(args) -> None:
    tenants = load_tenants(Path(args.tenants))
    for t in tenants:
        print(f"== {t['slug']} ==")
        dsn = compose_dsn(args.base_dsn, t["schema"])
        print(f'  -> ensure schema "{t["schema"]}"')
        ensure_schema(dsn, t["schema"])
        print("  -> apply schema")
        run_sql_file(dsn, SQL_SCHEMA)
    print("Done.")


def cmd_seed(args) -> None:
    if not SQL_SEED.exists():
        sys.exit(f"seed file not found: {SQL_SEED}")
    tenants = load_tenants(Path(args.tenants))
    for t in tenants:
        print(f"== {t['slug']} (seed) ==")
        dsn = compose_dsn(args.base_dsn, t["schema"])
        run_sql_file(dsn, SQL_SEED)
    print("Done.")


def cmd_print_env(args) -> None:
    tenants = load_tenants(Path(args.tenants))
    mapping = {t["slug"]: compose_dsn(args.base_dsn, t["schema"]) for t in tenants}
    print(json.dumps(mapping))


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    p1 = sub.add_parser("bootstrap", help="ensure tenant schemas + apply schema SQL")
    p1.add_argument("--tenants", required=True)
    p1.add_argument("--base-dsn", required=True)
    p1.set_defaults(func=cmd_bootstrap)

    p2 = sub.add_parser("seed", help="apply seed SQL to each tenant")
    p2.add_argument("--tenants", required=True)
    p2.add_argument("--base-dsn", required=True)
    p2.set_defaults(func=cmd_seed)

    p3 = sub.add_parser("print-env", help="print TENANT_DSN_MAP JSON (composed)")
    p3.add_argument("--tenants", required=True)
    p3.add_argument("--base-dsn", required=True)
    p3.set_defaults(func=cmd_print_env)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
