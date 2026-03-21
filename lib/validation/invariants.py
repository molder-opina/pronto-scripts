"""
Database Invariant Checker

Enforces database consistency rules for payment infrastructure.

Critical Invariants:
1. 1 idempotency_key → maximum 1 payment
2. Paid session → no new payments accepted
3. Outbox → always consistent with DB
4. Order state transitions → valid only through state machine

Rule: SQL validation with raw evidence (row counts, query output)
"""

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

import psycopg2

from .core import Evidence, ValidationEngine, ValidationResult, ValidationStatus


@dataclass
class DatabaseConfig:
    """Database connection configuration"""

    host: str
    port: int
    database: str
    user: str
    password: str

    @classmethod
    def from_env(cls) -> "DatabaseConfig":
        return cls(
            host=os.getenv("POSTGRES_HOST", "localhost"),
            port=int(os.getenv("POSTGRES_PORT", "5432")),
            database=os.getenv("POSTGRES_DB", "pronto"),
            user=os.getenv("POSTGRES_USER", "pronto"),
            password=os.getenv("POSTGRES_PASSWORD", ""),
        )


@dataclass
class InvariantCheck:
    """Database invariant check definition"""

    name: str
    description: str
    sql: str
    expected_rows: int  # 0 = should return no rows (no violations)
    severity: str = "critical"
    fix_suggestion: str = ""


# Critical Payment Invariants
PAYMENT_INVARIANTS = [
    InvariantCheck(
        name="idempotency_uniqueness",
        description="Each idempotency_key must have at most 1 payment",
        sql="""
            SELECT idempotency_key, COUNT(*) as payment_count
            FROM pronto_payments
            WHERE idempotency_key IS NOT NULL
            GROUP BY idempotency_key
            HAVING COUNT(*) > 1
        """,
        expected_rows=0,
        severity="critical",
        fix_suggestion="Remove duplicate payments or merge by idempotency_key",
    ),
    InvariantCheck(
        name="paid_session_no_new_payments",
        description="Paid sessions must not accept new payments",
        sql="""
            SELECT ds.id, ds.status, COUNT(p.id) as payment_count
            FROM pronto_dining_sessions ds
            LEFT JOIN pronto_payments p ON p.dining_session_id = ds.id
            WHERE ds.status = 'paid'
            AND p.created_at > ds.updated_at
            GROUP BY ds.id, ds.status
        """,
        expected_rows=0,
        severity="critical",
        fix_suggestion="Reject payments for sessions with status='paid'",
    ),
    InvariantCheck(
        name="payment_status_consistency",
        description="Payment status must match transaction state",
        sql="""
            SELECT p.id, p.status, p.amount, pt.transaction_id
            FROM pronto_payments p
            LEFT JOIN pronto_payment_transactions pt ON pt.payment_id = p.id
            WHERE p.status = 'paid'
            AND (pt.transaction_id IS NULL OR pt.status != 'succeeded')
        """,
        expected_rows=0,
        severity="high",
        fix_suggestion="Reconcile payment status with transaction provider",
    ),
    InvariantCheck(
        name="order_workflow_validity",
        description="Order workflow_status must be valid state",
        sql="""
            SELECT id, workflow_status
            FROM pronto_orders
            WHERE workflow_status NOT IN (
                'new', 'queued', 'preparing', 'ready', 'delivered', 'paid', 'cancelled'
            )
        """,
        expected_rows=0,
        severity="high",
        fix_suggestion="Use OrderStateMachine for all state transitions",
    ),
    InvariantCheck(
        name="session_status_validity",
        description="Session status must be valid state",
        sql="""
            SELECT id, status
            FROM pronto_dining_sessions
            WHERE status NOT IN (
                'open', 'active', 'awaiting_tip', 'awaiting_payment',
                'awaiting_payment_confirmation', 'paid', 'closed', 'merged'
            )
        """,
        expected_rows=0,
        severity="high",
        fix_suggestion="Validate session status through state machine",
    ),
    InvariantCheck(
        name="orphan_order_items",
        description="All order items must belong to valid orders",
        sql="""
            SELECT oi.id, oi.order_id
            FROM pronto_order_items oi
            LEFT JOIN pronto_orders o ON o.id = oi.order_id
            WHERE o.id IS NULL
        """,
        expected_rows=0,
        severity="high",
        fix_suggestion="Add foreign key constraint with ON DELETE CASCADE",
    ),
    InvariantCheck(
        name="duplicate_active_sessions",
        description="No duplicate active sessions per table",
        sql="""
            SELECT table_id, COUNT(*) as session_count
            FROM pronto_dining_sessions
            WHERE status IN ('open', 'active')
            GROUP BY table_id
            HAVING COUNT(*) > 1
        """,
        expected_rows=0,
        severity="medium",
        fix_suggestion="Close or merge duplicate sessions",
    ),
]


class InvariantChecker:
    """
    Database invariant validator

    Rule: SQL validation with raw evidence (row counts, query output)
    """

    def __init__(
        self, workspace_root: Path, db_config: Optional[DatabaseConfig] = None
    ):
        self.workspace_root = workspace_root
        self.engine = ValidationEngine(workspace_root)
        self.db_config = db_config or DatabaseConfig.from_env()
        self.violations: List[Dict[str, Any]] = []

    def get_connection(self):
        """Get database connection"""
        return psycopg2.connect(
            host=self.db_config.host,
            port=self.db_config.port,
            database=self.db_config.database,
            user=self.db_config.user,
            password=self.db_config.password,
        )

    def check_invariant(self, invariant: InvariantCheck) -> ValidationResult:
        """
        Check a single database invariant

        Rule: Must provide raw SQL output and row counts
        """
        try:
            conn = self.get_connection()
            cur = conn.cursor()

            cur.execute(invariant.sql)
            rows = cur.fetchall()
            columns = [desc[0] for desc in cur.description] if cur.description else []

            cur.close()
            conn.close()

            # Build evidence
            evidence = Evidence(
                stdout=f"Query returned {len(rows)} rows (expected: {invariant.expected_rows})",
                row_count=len(rows),
                raw_output="\n".join([f"{dict(zip(columns, row))}" for row in rows])
                if rows
                else "No violations found",
            )

            # Determine status
            if len(rows) > invariant.expected_rows:
                status = ValidationStatus.FAILED
                message = f"INVARIANT VIOLATED: {invariant.description}"
                severity = invariant.severity

                self.violations.extend(
                    [
                        {"check": invariant.name, "data": dict(zip(columns, row))}
                        for row in rows
                    ]
                )
            else:
                status = ValidationStatus.PASSED
                message = (
                    f"INVARIANT OK: {invariant.description} (verified {len(rows)} rows)"
                )
                severity = "info"

            result = ValidationResult(
                name=f"invariant-{invariant.name}",
                status=status,
                message=message,
                evidence=evidence,
                severity=severity,
                suggestions=[invariant.fix_suggestion]
                if status == ValidationStatus.FAILED
                else [],
            )

            self.engine.add_result(result)
            return result

        except Exception as e:
            evidence = Evidence(
                stderr=f"Database error: {str(e)}",
                return_code=-1,
            )

            result = ValidationResult(
                name=f"invariant-{invariant.name}",
                status=ValidationStatus.FAILED,
                message=f"CHECK FAILED: Could not verify invariant - {str(e)}",
                evidence=evidence,
                severity="critical",
                suggestions=[
                    "Verify database connection",
                    "Check if table exists",
                    "Ensure proper permissions",
                ],
            )

            self.engine.add_result(result)
            return result

    def check_all_invariants(
        self, invariants: Optional[List[InvariantCheck]] = None
    ) -> List[ValidationResult]:
        """
        Check all database invariants

        Rule: Negative validation - prove why DB is NOT corrupted
        """
        invariants = invariants or PAYMENT_INVARIANTS
        results = []

        for invariant in invariants:
            result = self.check_invariant(invariant)
            results.append(result)

        return results

    def check_idempotency(self) -> ValidationResult:
        """Specific check for idempotency uniqueness (most critical)"""
        invariant = InvariantCheck(
            name="idempotency_uniqueness_fast",
            description="CRITICAL: Each idempotency_key must have at most 1 payment",
            sql="""
                SELECT idempotency_key, COUNT(*) as payment_count
                FROM pronto_payments
                WHERE idempotency_key IS NOT NULL
                GROUP BY idempotency_key
                HAVING COUNT(*) > 1
            """,
            expected_rows=0,
            severity="critical",
            fix_suggestion="CRITICAL: Remove duplicate payments immediately",
        )
        return self.check_invariant(invariant)

    def get_violations_summary(self) -> Dict[str, Any]:
        """Get summary of all violations"""
        by_check = {}

        for v in self.violations:
            check_name = v["check"]
            if check_name not in by_check:
                by_check[check_name] = []
            by_check[check_name].append(v["data"])

        return {
            "total_violations": len(self.violations),
            "by_check": by_check,
            "critical_count": sum(
                1
                for i in PAYMENT_INVARIANTS
                if i.severity == "critical" and i.name in by_check
            ),
        }
