"""
Migrate data from a legacy MySQL database into Supabase Postgres.

Usage:
  python scripts/migrate_data_to_supabase.py \
      --source-url mysql+pymysql://user:pass@host:3306/dbname \
      --batch-size 500 \
      --truncate

Notes:
- Requires SQLAlchemy and a MySQL driver (e.g. pymysql) in the environment.
- Target connection uses SUPABASE_* env vars (same as the app).
"""

from __future__ import annotations

import argparse
import os
import sys
from collections.abc import Iterable
from pathlib import Path
from typing import Any

from sqlalchemy import MetaData, Table, create_engine


def _chunked(rows: Iterable[dict[str, Any]], size: int) -> Iterable[list[dict[str, Any]]]:
    batch: list[dict[str, Any]] = []
    for row in rows:
        batch.append(row)
        if len(batch) >= size:
            yield batch
            batch = []
    if batch:
        yield batch


def _build_target_url() -> str:
    load_config = _load_config()
    config = load_config(os.getenv("APP_NAME", "pronto"))
    return os.getenv("DATABASE_URL") or config.sqlalchemy_uri


def _load_config():
    """Load the shared config loader after adjusting sys.path."""
    sys.path.insert(0, str(Path(__file__).parent / ".." / "build"))
    from pronto_shared.config import load_config

    return load_config


def _truncate_table(engine, table: Table) -> None:
    preparer = engine.dialect.identifier_preparer
    table_name = preparer.quote(table.name)
    schema_name = preparer.quote(table.schema) if table.schema else None
    qualified_name = f"{schema_name}.{table_name}" if schema_name else table_name
    sql = f"TRUNCATE TABLE {qualified_name} RESTART IDENTITY CASCADE"
    with engine.begin() as conn:
        conn.exec_driver_sql(sql)


def migrate(source_url: str, batch_size: int, truncate: bool) -> None:
    source_engine = create_engine(source_url)
    target_engine = create_engine(_build_target_url())

    metadata = MetaData()
    metadata.reflect(bind=source_engine)

    if not metadata.tables:
        print("No tables found in source database.")
        return

    for table in metadata.sorted_tables:
        print(f"Migrating {table.name}...")
        if truncate:
            _truncate_table(target_engine, table)

        with source_engine.connect() as conn:
            result = conn.execute(table.select())
            rows = [dict(row._mapping) for row in result]

        if not rows:
            print(f"  - No rows to migrate for {table.name}")
            continue

        for batch in _chunked(rows, batch_size):
            with target_engine.begin() as conn:
                conn.execute(table.insert(), batch)

        print(f"  - Migrated {len(rows)} rows")

    print("Migration completed.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Migrate MySQL data into Supabase Postgres.")
    parser.add_argument(
        "--source-url", required=True, help="SQLAlchemy URL for the MySQL source database."
    )
    parser.add_argument("--batch-size", type=int, default=500, help="Rows per batch insert.")
    parser.add_argument(
        "--truncate",
        action="store_true",
        help="Truncate target tables before inserting rows.",
    )
    args = parser.parse_args()

    try:
        migrate(args.source_url, args.batch_size, args.truncate)
    except Exception as exc:  # pragma: no cover - CLI script
        print(f"Migration failed: {exc}")
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
