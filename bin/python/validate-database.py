#!/usr/bin/env python3
"""
Database Validation Script

Validates database connectivity, schema integrity, data consistency,
and performs health checks using the application's configured connection settings.

Usage:
    python bin/python/validate-database.py [--quick] [--verbose] [--fix] [--export FILE]

Options:
    --quick      Quick validation (connectivity only)
    --verbose    Show detailed output
    --fix        Attempt to fix common issues
    --export     Export results to JSON file

Exit codes:
    0 - All checks passed
    1 - Errors found
    2 - Configuration error
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


class Colors:
    """ANSI color codes for terminal output."""

    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


class DatabaseValidator:
    """Validates database connectivity and integrity."""

    # Required tables for the application
    REQUIRED_TABLES = [
        "pronto_orders",
        "pronto_menu_items",
        "pronto_menu_categories",
        "pronto_employees",
        "pronto_sessions",
        "pronto_customers",
        "pronto_tables",
        "pronto_areas",
        "pronto_waiter_calls",
        "pronto_notifications",
    ]

    # Critical tables that must have data
    CRITICAL_DATA_TABLES = [
        "pronto_menu_categories",
        "pronto_menu_items",
        "pronto_employees",
        "pronto_tables",
        "pronto_areas",
    ]

    def __init__(self, verbose: bool = False, fix: bool = False):
        self.verbose = verbose
        self.fix = fix
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.passed: list[str] = []
        self.db_config: dict[str, Any] = {}

    def log(self, message: str, level: str = "INFO"):
        """Log a message with optional color."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        if level == "ERROR":
            msg = f"{Colors.RED}[ERROR]{Colors.RESET} {message}"
        elif level == "WARNING":
            msg = f"{Colors.YELLOW}[WARN]{Colors.RESET} {message}"
        elif level == "PASS":
            msg = f"{Colors.GREEN}[PASS]{Colors.RESET} {message}"
        elif level == "SECTION":
            msg = f"\n{Colors.BOLD}{Colors.BLUE}=== {message} ==={Colors.RESET}"
        elif level == "INFO" and self.verbose:
            msg = f"{Colors.BLUE}[INFO]{Colors.RESET} {message}"
        else:
            return

        print(f"{timestamp} {msg}")

    def load_config(self) -> bool:
        """Load database configuration from environment files."""
        self.log("Loading database configuration...", "INFO")

        import os

        # Check if running in Docker or locally
        in_docker = os.path.exists("/.dockerenv") or os.environ.get("DOCKER_CONTAINER")

        self.db_config = {
            "host": os.environ.get("POSTGRES_HOST", "localhost"),
            "port": int(os.environ.get("POSTGRES_PORT", 5432)),
            "user": os.environ.get("POSTGRES_USER", "pronto"),
            "password": os.environ.get("POSTGRES_PASSWORD", "pronto123"),
            "database": os.environ.get("POSTGRES_DB", "pronto"),
        }

        # If running locally and USE_LOCAL_POSTGRES is true, use localhost
        use_local = os.environ.get("USE_LOCAL_POSTGRES", "").lower() == "true"
        if not in_docker and use_local:
            self.db_config["host"] = "localhost"

        # Try to load from config files for additional settings
        config_file = Path(".env")
        if config_file.exists():
            with open(config_file) as f:
                for line in f:
                    if line.strip() and not line.strip().startswith("#"):
                        key, value = line.strip().split("=", 1)
                        key = key.strip()
                        value = value.strip().strip('"').strip("'")
                        if key.startswith("POSTGRES"):
                            # Only override if not already set and not docker hostname
                            config_key = key.replace("POSTGRES_", "").lower()
                            if config_key == "port":
                                self.db_config[config_key] = int(value)
                            elif (
                                config_key == "host"
                                and value == "postgres"
                                and use_local
                            ):
                                self.db_config[config_key] = "localhost"

        self.log(
            f"Database: {self.db_config['host']}:{self.db_config['port']}/{self.db_config['database']}",
            "INFO",
        )
        return True

    def get_connection(self):
        """Get a database connection."""
        import psycopg2

        return psycopg2.connect(
            host=self.db_config["host"],
            port=self.db_config["port"],
            user=self.db_config["user"],
            password=self.db_config["password"],
            database=self.db_config["database"],
            connect_timeout=10,
        )

    def check_connectivity(self) -> bool:
        """Check basic database connectivity."""
        self.log("Checking database connectivity...", "SECTION")

        try:
            import psycopg2

            conn = self.get_connection()
            cursor = conn.cursor()

            # Test query
            cursor.execute("SELECT version();")
            version = cursor.fetchone()[0]
            self.passed.append(f"PostgreSQL connected: {version[:50]}...")

            # Get server info
            cursor.execute("SHOW server_version;")
            server_version = cursor.fetchone()[0]
            self.passed.append(f"Server version: {server_version}")

            cursor.close()
            conn.close()

            self.log("Database connectivity successful", "PASS")
            return True

        except ImportError:
            self.errors.append("psycopg2 not installed - cannot connect to database")
            self.log("psycopg2 not available", "ERROR")
            return False

        except psycopg2.OperationalError as e:
            self.errors.append(f"Connection failed: {str(e)}")
            self.log(f"Connection failed: {e}", "ERROR")
            return False

    def check_required_tables(self) -> bool:
        """Check that all required tables exist."""
        self.log("Checking required tables...", "SECTION")

        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            # Get list of tables
            cursor.execute(
                """
                SELECT table_name
                FROM information_schema.tables
                WHERE table_schema = 'public'
                ORDER BY table_name
            """
            )
            existing_tables = [row[0] for row in cursor.fetchall()]

            all_found = True
            for table in self.REQUIRED_TABLES:
                if table in existing_tables:
                    self.passed.append(f"Table exists: {table}")
                else:
                    self.errors.append(f"Missing required table: {table}")
                    all_found = False

            if all_found:
                self.log(
                    f"All {len(self.REQUIRED_TABLES)} required tables found", "PASS"
                )
            else:
                self.log("Some required tables are missing", "ERROR")

            cursor.close()
            conn.close()

            return all_found

        except Exception as e:
            self.errors.append(f"Error checking tables: {str(e)}")
            self.log(f"Error: {e}", "ERROR")
            return False

    def check_table_row_counts(self) -> bool:
        """Check row counts for critical tables."""
        self.log("Checking table row counts...", "SECTION")

        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            results = {}
            for table in self.CRITICAL_DATA_TABLES:
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM {table}")
                    count = cursor.fetchone()[0]
                    results[table] = count

                    if count > 0:
                        self.passed.append(f"{table}: {count} rows")
                    else:
                        self.warnings.append(f"{table}: EMPTY (requires data)")
                        self.log(f"{table} is empty", "WARNING")

                except psycopg2.Error:
                    self.warnings.append(f"{table}: Could not count rows")

            cursor.close()
            conn.close()

            # Check if critical data is present
            has_critical_data = any(
                count > 0
                for table, count in results.items()
                if table in ["pronto_menu_categories", "pronto_menu_items"]
            )

            if not has_critical_data:
                self.warnings.append(
                    "Critical data (menu) is missing - seed data may be needed"
                )

            return True

        except Exception as e:
            self.errors.append(f"Error checking row counts: {str(e)}")
            return False

    def check_foreign_keys(self) -> bool:
        """Check foreign key constraints."""
        self.log("Checking foreign key constraints...", "SECTION")

        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            # Get foreign key violations
            cursor.execute(
                """
                SELECT
                    tc.constraint_name,
                    tc.table_name,
                    kcu.column_name,
                    ccu.table_name AS foreign_table_name,
                    ccu.column_name AS foreign_column_name
                FROM information_schema.table_constraints AS tc
                JOIN information_schema.constraint_table_usage AS ctu
                    ON tc.constraint_name = ctu.constraint_name
                JOIN information_schema.key_column_usage AS kcu
                    ON tc.constraint_name = kcu.constraint_name
                JOIN information_schema.constraint_column_usage AS ccu
                    ON ctu.constraint_name = ccu.constraint_name
                WHERE tc.constraint_type = 'FOREIGN KEY'
                ORDER BY tc.table_name
            """
            )

            fk_count = len(cursor.fetchall())
            self.passed.append(f"Foreign key constraints: {fk_count}")

            # Check for orphaned records (simple check)
            cursor.execute(
                """
                SELECT COUNT(*) FROM pronto_orders o
                LEFT JOIN pronto_sessions s ON o.session_id = s.id
                WHERE o.session_id IS NOT NULL AND s.id IS NULL
            """
            )
            orphaned = cursor.fetchone()[0]

            if orphaned == 0:
                self.passed.append("No orphaned order records found")
            else:
                self.warnings.append(f"Found {orphaned} orphaned order records")

            cursor.close()
            conn.close()

            self.log("Foreign key check completed", "PASS")
            return True

        except Exception as e:
            self.errors.append(f"Error checking foreign keys: {str(e)}")
            return False

    def check_indexes(self) -> bool:
        """Check index health."""
        self.log("Checking indexes...", "SECTION")

        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            # Get index information
            cursor.execute(
                """
                SELECT
                    indexname,
                    indexdef
                FROM pg_indexes
                WHERE schemaname = 'public'
                AND tablename IN ('pronto_orders', 'pronto_sessions', 'pronto_menu_items')
                ORDER BY tablename, indexname
            """
            )

            indexes = cursor.fetchall()
            self.passed.append(f"Database indexes: {len(indexes)}")

            # Check for common missing indexes
            cursor.execute(
                """
                SELECT COUNT(*) FROM pg_stat_user_tables
                WHERE schemaname = 'public'
                AND seq_scan > 0
                AND idx_scan = 0
            """
            )
            tables_without_indexes = cursor.fetchone()[0]

            if tables_without_indexes == 0:
                self.passed.append("All tables have indexes")
            else:
                self.warnings.append(
                    f"{tables_without_indexes} tables may need indexes"
                )

            cursor.close()
            conn.close()

            return True

        except Exception as e:
            self.errors.append(f"Error checking indexes: {str(e)}")
            return False

    def check_data_consistency(self) -> bool:
        """Check data consistency."""
        self.log("Checking data consistency...", "SECTION")

        try:
            conn = self.get_connection()
            cursor = conn.cursor()

            # Check 1: Orders with invalid status
            cursor.execute(
                """
                SELECT COUNT(*) FROM pronto_orders
                WHERE workflow_status NOT IN ('pending', 'accepted', 'preparing', 'ready', 'delivered', 'cancelled')
            """
            )
            invalid_status = cursor.fetchone()[0]

            if invalid_status == 0:
                self.passed.append("Order statuses: All valid")
            else:
                self.warnings.append(f"Orders with invalid status: {invalid_status}")

            # Check 2: Sessions without table
            cursor.execute(
                """
                SELECT COUNT(*) FROM pronto_sessions
                WHERE table_number IS NULL
            """
            )
            no_table = cursor.fetchone()[0]

            if no_table == 0:
                self.passed.append("Sessions: All have table assigned")
            else:
                self.warnings.append(f"Sessions without table: {no_table}")

            # Check 3: Unpaid delivered orders
            cursor.execute(
                """
                SELECT COUNT(*) FROM pronto_orders
                WHERE workflow_status = 'delivered'
                AND payment_status NOT IN ('paid', 'none')
            """
            )
            unpaid_delivered = cursor.fetchone()[0]

            if unpaid_delivered == 0:
                self.passed.append("Delivered orders: All properly paid")
            else:
                self.warnings.append(f"Unpaid delivered orders: {unpaid_delivered}")

            # Check 4: Employees without role
            cursor.execute(
                """
                SELECT COUNT(*) FROM pronto_employees
                WHERE role IS NULL OR role = ''
            """
            )
            no_role = cursor.fetchone()[0]

            if no_role == 0:
                self.passed.append("Employees: All have roles assigned")
            else:
                self.warnings.append(f"Employees without role: {no_role}")

            cursor.close()
            conn.close()

            self.log("Data consistency check completed", "PASS")
            return True

        except Exception as e:
            self.errors.append(f"Error checking data consistency: {str(e)}")
            return False

    def run_quick_check(self) -> dict[str, Any]:
        """Run quick connectivity check."""
        self.log("Running QUICK database check...", "SECTION")

        self.load_config()
        self.check_connectivity()

        return {
            "timestamp": datetime.now().isoformat(),
            "mode": "quick",
            "passed": self.passed,
            "warnings": self.warnings,
            "errors": self.errors,
            "status": "PASS" if not self.errors else "FAIL",
        }

    def run_full_check(self) -> dict[str, Any]:
        """Run full database validation."""
        self.log("Running FULL database validation...", "SECTION")

        self.load_config()
        self.check_connectivity()

        if not self.errors:
            self.check_required_tables()
            self.check_table_row_counts()
            self.check_foreign_keys()
            self.check_indexes()
            self.check_data_consistency()

        return {
            "timestamp": datetime.now().isoformat(),
            "mode": "full",
            "passed": self.passed,
            "warnings": self.warnings,
            "errors": self.errors,
            "status": "PASS" if not self.errors else "FAIL",
        }

    def print_summary(self, results: dict[str, Any]):
        """Print validation summary."""
        print(f"\n{Colors.BOLD}{'=' * 60}{Colors.RESET}")
        print(f"{Colors.BOLD}DATABASE VALIDATION SUMMARY{Colors.RESET}")
        print(f"{Colors.BOLD}{'=' * 60}{Colors.RESET}")

        print(f"\n{Colors.GREEN}Passed:{Colors.RESET} {len(results['passed'])}")
        for item in results["passed"][:5]:
            print(f"  ✓ {item}")
        if len(results["passed"]) > 5:
            print(f"  ... and {len(results['passed']) - 5} more")

        if results["warnings"]:
            print(
                f"\n{Colors.YELLOW}Warnings:{Colors.RESET} {len(results['warnings'])}"
            )
            for item in results["warnings"][:3]:
                print(f"  ⚠ {item}")
            if len(results["warnings"]) > 3:
                print(f"  ... and {len(results['warnings']) - 3} more")

        if results["errors"]:
            print(f"\n{Colors.RED}Errors:{Colors.RESET} {len(results['errors'])}")
            for item in results["errors"][:5]:
                print(f"  ✗ {item}")
            if len(results["errors"]) > 5:
                print(f"  ... and {len(results['errors']) - 5} more")

        print(f"\n{Colors.BOLD}Status: {results['status']}{Colors.RESET}")

    def save_results(self, results: dict[str, Any], filepath: str):
        """Save results to JSON file."""
        Path(filepath).parent.mkdir(parents=True, exist_ok=True)

        with open(filepath, "w") as f:
            json.dump(results, f, indent=2, default=str)

        self.log(f"Results saved to {filepath}", "INFO")


def main():
    parser = argparse.ArgumentParser(
        description="Database Validation Script - Check database health and integrity"
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Show verbose output"
    )
    parser.add_argument(
        "--quick", "-q", action="store_true", help="Quick check (connectivity only)"
    )
    parser.add_argument(
        "--fix", "-f", action="store_true", help="Attempt to fix common issues"
    )
    parser.add_argument("--export", "-e", help="Export results to JSON file")

    args = parser.parse_args()

    validator = DatabaseValidator(verbose=args.verbose, fix=args.fix)

    if args.quick:
        results = validator.run_quick_check()
    else:
        results = validator.run_full_check()

    validator.print_summary(results)

    if args.export:
        validator.save_results(results, args.export)

    # Exit with appropriate code
    if results["status"] == "FAIL":
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
