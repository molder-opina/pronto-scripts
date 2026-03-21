"""
Extended Database Invariants for PRONTO

Additional domain-specific invariants beyond the core payment checks.
"""

from dataclasses import dataclass
from typing import List

from .invariants import InvariantCheck


# Order Lifecycle Invariants
ORDER_LIFECYCLE_INVARIANTS = [
    InvariantCheck(
        name="order_without_session",
        description="All orders must belong to a valid dining session",
        sql="""
            SELECT o.id, o.dining_session_id
            FROM pronto_orders o
            LEFT JOIN pronto_dining_sessions ds ON ds.id = o.dining_session_id
            WHERE o.dining_session_id IS NOT NULL
            AND ds.id IS NULL
        """,
        expected_rows=0,
        severity="high",
        fix_suggestion="Add foreign key constraint with ON DELETE CASCADE",
    ),
    InvariantCheck(
        name="cancelled_order_with_payment",
        description="Cancelled orders should not have successful payments",
        sql="""
            SELECT o.id, o.workflow_status, p.id as payment_id, p.status
            FROM pronto_orders o
            JOIN pronto_payments p ON p.order_id = o.id
            WHERE o.workflow_status = 'cancelled'
            AND p.status = 'paid'
        """,
        expected_rows=0,
        severity="critical",
        fix_suggestion="Refund payment or restore order status",
    ),
    InvariantCheck(
        name="order_total_mismatch",
        description="Order total should match sum of items",
        sql="""
            SELECT 
                o.id,
                o.total_amount,
                COALESCE(SUM(oi.subtotal), 0) as items_total,
                ABS(o.total_amount - COALESCE(SUM(oi.subtotal), 0)) as difference
            FROM pronto_orders o
            LEFT JOIN pronto_order_items oi ON oi.order_id = o.id
            GROUP BY o.id, o.total_amount
            HAVING ABS(o.total_amount - COALESCE(SUM(oi.subtotal), 0)) > 0.01
        """,
        expected_rows=0,
        severity="high",
        fix_suggestion="Recalculate order total from items",
    ),
]

# Session Invariants
SESSION_INVARIANTS = [
    InvariantCheck(
        name="session_without_table",
        description="All sessions must belong to a valid table",
        sql="""
            SELECT ds.id, ds.table_id
            FROM pronto_dining_sessions ds
            LEFT JOIN pronto_tables t ON t.id = ds.table_id
            WHERE ds.table_id IS NOT NULL
            AND t.id IS NULL
        """,
        expected_rows=0,
        severity="high",
        fix_suggestion="Add foreign key constraint",
    ),
    InvariantCheck(
        name="open_session_no_activity",
        description="Open sessions should have recent activity (within 24h)",
        sql="""
            SELECT id, status, created_at, updated_at
            FROM pronto_dining_sessions
            WHERE status IN ('open', 'active')
            AND updated_at < NOW() - INTERVAL '24 hours'
        """,
        expected_rows=0,
        severity="medium",
        fix_suggestion="Auto-close stale sessions",
    ),
    InvariantCheck(
        name="session_with_negative_balance",
        description="Sessions should not have negative total amounts",
        sql="""
            SELECT id, total_amount, status
            FROM pronto_dining_sessions
            WHERE total_amount < 0
        """,
        expected_rows=0,
        severity="high",
        fix_suggestion="Investigate and correct negative amounts",
    ),
]

# Menu/Inventory Invariants
MENU_INVARIANTS = [
    InvariantCheck(
        name="orphan_menu_items",
        description="All menu items must belong to a valid category",
        sql="""
            SELECT mi.id, mi.category_id
            FROM pronto_menu_items mi
            LEFT JOIN pronto_menu_categories mc ON mc.id = mi.category_id
            WHERE mi.category_id IS NOT NULL
            AND mc.id IS NULL
        """,
        expected_rows=0,
        severity="medium",
        fix_suggestion="Add foreign key constraint or set category to NULL",
    ),
    InvariantCheck(
        name="product_without_price",
        description="Active products must have a price",
        sql="""
            SELECT id, name, price, is_available
            FROM pronto_menu_items
            WHERE is_available = true
            AND (price IS NULL OR price <= 0)
        """,
        expected_rows=0,
        severity="high",
        fix_suggestion="Set price for active products",
    ),
    InvariantCheck(
        name="duplicate_qr_codes",
        description="QR codes must be unique per table",
        sql="""
            SELECT qr_code, COUNT(*) as table_count
            FROM pronto_tables
            WHERE qr_code IS NOT NULL
            GROUP BY qr_code
            HAVING COUNT(*) > 1
        """,
        expected_rows=0,
        severity="critical",
        fix_suggestion="Regenerate duplicate QR codes",
    ),
]

# Employee/Auth Invariants
EMPLOYEE_INVARIANTS = [
    InvariantCheck(
        name="employee_without_role",
        description="All employees must have at least one role",
        sql="""
            SELECT e.id, e.employee_number
            FROM pronto_employees e
            LEFT JOIN pronto_employee_roles er ON er.employee_id = e.id
            WHERE er.employee_id IS NULL
        """,
        expected_rows=0,
        severity="high",
        fix_suggestion="Assign role to employee or deactivate",
    ),
    InvariantCheck(
        name="inactive_employee_with_active_session",
        description="Inactive employees should not have active sessions",
        sql="""
            SELECT e.id, e.is_active, s.id as session_id, s.status
            FROM pronto_employees e
            JOIN pronto_sessions s ON s.employee_id = e.id
            WHERE e.is_active = false
            AND s.status = 'active'
        """,
        expected_rows=0,
        severity="critical",
        fix_suggestion="Terminate employee sessions",
    ),
    InvariantCheck(
        name="duplicate_active_sessions_per_employee",
        description="Employees should not have multiple active sessions",
        sql="""
            SELECT employee_id, COUNT(*) as session_count
            FROM pronto_sessions
            WHERE status = 'active'
            GROUP BY employee_id
            HAVING COUNT(*) > 1
        """,
        expected_rows=0,
        severity="medium",
        fix_suggestion="Close duplicate sessions",
    ),
]

# All Extended Invariants
ALL_EXTENDED_INVARIANTS = (
    ORDER_LIFECYCLE_INVARIANTS
    + SESSION_INVARIANTS
    + MENU_INVARIANTS
    + EMPLOYEE_INVARIANTS
)


def get_invariants_by_category() -> dict:
    """Get invariants grouped by category"""
    return {
        "order_lifecycle": ORDER_LIFECYCLE_INVARIANTS,
        "session": SESSION_INVARIANTS,
        "menu": MENU_INVARIANTS,
        "employee": EMPLOYEE_INVARIANTS,
    }
