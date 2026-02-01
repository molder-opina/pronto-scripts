#!/usr/bin/env python3
"""
Script to recalculate order totals with correct tax logic.

This script fixes orders that were created with the old (incorrect) tax calculation
where tax was added on top of prices that already included tax.

With the new system (tax_included mode), prices already include tax:
- display_price = $9.50 (includes tax)
- price_base = $9.50 / 1.16 = $8.19
- tax_amount = $8.19 * 0.16 = $1.31
- total = $8.19 + $1.31 = $9.50 (same as display price)
"""

import sys
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path

# Add project root to path
project_root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(project_root / "build"))

from sqlalchemy import select  # noqa: E402

from shared.db import get_session  # noqa: E402
from shared.models import Order  # noqa: E402
from shared.services.price_service import (  # noqa: E402
    calculate_price_breakdown,
    get_price_display_mode,
)


def recalculate_order(order: Order, tax_rate: Decimal, dry_run: bool = True) -> dict:
    """
    Recalculate an order's totals with the correct tax logic.

    Returns dict with old and new values for comparison.
    """
    price_mode = get_price_display_mode()

    # Store old values
    old_subtotal = Decimal(str(order.subtotal))
    old_tax = Decimal(str(order.tax_amount))
    old_total = Decimal(str(order.total_amount))

    # Calculate new values
    subtotal_base = Decimal("0")

    for order_item in order.items:
        # Calculate base price for item
        item_display_price = Decimal(str(order_item.unit_price))
        item_breakdown = calculate_price_breakdown(item_display_price, tax_rate, price_mode)
        item_base_price = item_breakdown["price_base"] * Decimal(str(order_item.quantity))

        # Calculate base price for modifiers
        modifier_base_total = Decimal("0")
        for modifier in order_item.modifiers:
            modifier_display_price = Decimal(str(modifier.unit_price_adjustment)) * Decimal(
                str(modifier.quantity)
            )
            mod_breakdown = calculate_price_breakdown(modifier_display_price, tax_rate, price_mode)
            modifier_base_total += mod_breakdown["price_base"]

        subtotal_base += item_base_price + modifier_base_total

    # Calculate tax on base subtotal
    new_tax = (subtotal_base * tax_rate).quantize(Decimal("0.01"), ROUND_HALF_UP)
    new_total = subtotal_base + new_tax

    # Add tip if exists
    if order.tip_amount and order.tip_amount > 0:
        new_total += Decimal(str(order.tip_amount))

    result = {
        "order_id": order.id,
        "old": {
            "subtotal": float(old_subtotal),
            "tax": float(old_tax),
            "total": float(old_total),
        },
        "new": {
            "subtotal": float(subtotal_base),
            "tax": float(new_tax),
            "total": float(new_total),
        },
        "difference": {
            "subtotal": float(subtotal_base - old_subtotal),
            "tax": float(new_tax - old_tax),
            "total": float(new_total - old_total),
        },
        "changed": abs(new_total - old_total) > Decimal("0.01"),
    }

    # Apply changes if not dry run
    if not dry_run and result["changed"]:
        order.subtotal = float(subtotal_base)
        order.tax_amount = float(new_tax)
        order.total_amount = float(new_total)

        # Recompute session totals if order has a session
        if order.session:
            order.session.recompute_totals()

    return result


def main():
    """
    Main function to recalculate all orders.
    """
    import argparse

    parser = argparse.ArgumentParser(description="Recalculate order totals with correct tax logic")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=True,
        help="Show what would change without applying (default: True)",
    )
    parser.add_argument(
        "--apply", action="store_true", help="Actually apply the changes to the database"
    )
    parser.add_argument("--order-id", type=int, help="Recalculate only a specific order")
    parser.add_argument(
        "--tax-rate", type=float, default=0.16, help="Tax rate to use (default: 0.16)"
    )

    args = parser.parse_args()

    dry_run = not args.apply
    tax_rate = Decimal(str(args.tax_rate))

    print("=" * 80)
    print("RECALCULATE ORDER TOTALS WITH CORRECT TAX LOGIC")
    print("=" * 80)
    print(f"Mode: {'DRY RUN (no changes will be applied)' if dry_run else 'APPLY CHANGES'}")
    print(f"Tax rate: {tax_rate} ({float(tax_rate) * 100}%)")
    print(f"Price mode: {get_price_display_mode()}")
    print()

    if not dry_run:
        confirm = input("⚠️  This will modify the database. Are you sure? (yes/no): ")
        if confirm.lower() != "yes":
            print("Aborted.")
            return
        print()

    with get_session() as session:
        # Get orders to recalculate
        query = select(Order).join(Order.items)

        if args.order_id:
            query = query.where(Order.id == args.order_id)

        orders = session.execute(query).unique().scalars().all()

        print(f"Found {len(orders)} orders to process")
        print()

        changed_orders = []
        unchanged_orders = []

        for order in orders:
            result = recalculate_order(order, tax_rate, dry_run)

            if result["changed"]:
                changed_orders.append(result)
                print(f"Order #{result['order_id']:4d} - CHANGED")
                print(
                    f"  Old: subtotal=${result['old']['subtotal']:7.2f} + tax=${result['old']['tax']:6.2f} = ${result['old']['total']:7.2f}"
                )
                print(
                    f"  New: subtotal=${result['new']['subtotal']:7.2f} + tax=${result['new']['tax']:6.2f} = ${result['new']['total']:7.2f}"
                )
                print(
                    f"  Diff:         ${result['difference']['subtotal']:7.2f}       ${result['difference']['tax']:6.2f}    ${result['difference']['total']:7.2f}"
                )
                print()
            else:
                unchanged_orders.append(result)

        if not dry_run:
            session.commit()
            print("✅ Changes committed to database")

        print()
        print("=" * 80)
        print("SUMMARY")
        print("=" * 80)
        print(f"Total orders processed: {len(orders)}")
        print(f"Orders changed: {len(changed_orders)}")
        print(f"Orders unchanged: {len(unchanged_orders)}")

        if changed_orders:
            total_diff = sum(o["difference"]["total"] for o in changed_orders)
            print(f"Total difference: ${total_diff:.2f}")

        if dry_run and changed_orders:
            print()
            print("⚠️  This was a DRY RUN. No changes were applied.")
            print("   Run with --apply to actually update the database.")


if __name__ == "__main__":
    main()
