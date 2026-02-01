#!/usr/bin/env python3
"""
Database Validation Script

Usage:
    python bin/validate-database.py [--quick]
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path

RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"
BOLD = "\033[1m"


def log(msg, level="INFO"):
    ts = datetime.now().strftime("%H:%M:%S")
    if level == "ERROR":
        print(f"{RED}[ERROR]{RESET} {msg}")
    elif level == "PASS":
        print(f"{GREEN}[PASS]{RESET} {msg}")
    elif level == "WARN":
        print(f"{YELLOW}[WARN]{RESET} {msg}")
    else:
        print(f"{BLUE}[INFO]{RESET} {msg}")


def load_config():
    import os

    cfg = {
        "host": os.environ.get("POSTGRES_HOST", "localhost"),
        "port": int(os.environ.get("POSTGRES_PORT", 5432)),
        "user": os.environ.get("POSTGRES_USER", "pronto"),
        "password": os.environ.get("POSTGRES_PASSWORD", "pronto123"),
        "database": os.environ.get("POSTGRES_DB", "pronto"),
    }
    use_local = os.environ.get("USE_LOCAL_POSTGRES", "").lower() == "true"
    if use_local and cfg["host"] == "postgres":
        cfg["host"] = "localhost"
    return cfg


def check_connectivity(cfg):
    log("Checking database connectivity...", "INFO")
    try:
        import psycopg2

        conn = psycopg2.connect(**cfg, connect_timeout=10)
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()[0]
        log(f"PostgreSQL connected: {version[:50]}...", "PASS")
        cursor.close()
        conn.close()
        return True
    except ImportError:
        log("psycopg2 not installed", "ERROR")
        return False
    except Exception as e:
        log(f"Connection failed: {e}", "ERROR")
        return False


def check_tables(cfg):
    log("Checking required tables...", "INFO")
    required = [
        "pronto_orders",
        "pronto_menu_items",
        "pronto_menu_categories",
        "pronto_employees",
        "pronto_sessions",
        "pronto_tables",
    ]
    try:
        import psycopg2

        conn = psycopg2.connect(**cfg, connect_timeout=10)
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = 'public'
        """
        )
        existing = [r[0] for r in cursor.fetchall()]
        all_found = True
        for table in required:
            if table in existing:
                log(f"Table exists: {table}", "PASS")
            else:
                log(f"Missing table: {table}", "ERROR")
                all_found = False
        cursor.close()
        conn.close()
        return all_found
    except Exception as e:
        log(f"Error: {e}", "ERROR")
        return False


def run_quick():
    print(f"\n{BOLD}{BLUE}=== QUICK DATABASE CHECK ==={RESET}\n")
    cfg = load_config()
    log(f"Database: {cfg['host']}:{cfg['port']}/{cfg['database']}", "INFO")
    success = check_connectivity(cfg)
    if success:
        print(f"\n{GREEN}{BOLD}✅ Database connection successful{RESET}")
        sys.exit(0)
    else:
        print(f"\n{RED}{BOLD}❌ Database connection failed{RESET}")
        sys.exit(1)


def run_full():
    print(f"\n{BOLD}{BLUE}=== FULL DATABASE VALIDATION ==={RESET}\n")
    cfg = load_config()
    log(f"Database: {cfg['host']}:{cfg['port']}/{cfg['database']}", "INFO")

    if not check_connectivity(cfg):
        print(f"\n{RED}{BOLD}❌ Validation failed{RESET}")
        sys.exit(1)

    check_tables(cfg)
    print(f"\n{GREEN}{BOLD}✅ Database validation complete{RESET}")
    sys.exit(0)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Database Validation Script")
    parser.add_argument("--quick", action="store_true", help="Quick check")
    args = parser.parse_args()

    if args.quick:
        run_quick()
    else:
        run_full()
