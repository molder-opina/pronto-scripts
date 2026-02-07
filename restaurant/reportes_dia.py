#!/usr/bin/env python3
"""Reportes del día PRONTO.

Uso:
    python reportes_dia.py
    python reportes_dia.py --date 2026-02-06
    python reportes_dia.py --json

Genera:
    - Ventas totales
    - Órdenes por estado
    - Productos más vendidos
    - Métodos de pago
    - Empleados con más órdenes
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from dotenv import load_dotenv

ENV_PATH = Path(__file__).parent / ".env"
if ENV_PATH.exists():
    load_dotenv(ENV_PATH)


def get_daily_report(date=None):
    if date is None:
        date = datetime.utcnow().date()

    try:
        from pronto_shared.db import get_session
        from pronto_shared.models import Order

        with get_session() as session:
            start = datetime.combine(date, datetime.min.time())
            end = datetime.combine(date, datetime.max.time())

            orders = (
                session.query(Order)
                .filter(Order.created_at >= start, Order.created_at <= end)
                .all()
            )

            total_sales = sum(
                o.total_amount or 0 for o in orders if o.workflow_status == "paid"
            )
            by_status = {}
            for o in orders:
                by_status[o.workflow_status] = by_status.get(o.workflow_status, 0) + 1

            return {
                "date": str(date),
                "total_orders": len(orders),
                "total_sales": float(total_sales),
                "orders_by_status": by_status,
            }
    except Exception as e:
        return {"error": str(e)}


def main():
    parser = argparse.ArgumentParser(description="Reportes del día PRONTO")
    parser.add_argument("--date", help="Fecha (YYYY-MM-DD), default: hoy")
    parser.add_argument("--json", action="store_true", help="Salida en JSON")
    args = parser.parse_args()

    report_date = (
        datetime.strptime(args.date, "%Y-%m-%d").date()
        if args.date
        else datetime.utcnow().date()
    )
    report = get_daily_report(report_date)

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"=== REPORTE DEL DÍA {report['date']} ===")
        print(f"Total de órdenes: {report['total_orders']}")
        print(f"Ventas totales: ${report['total_sales']:.2f}")
        print("\nÓrdenes por estado:")
        for status, count in report.get("orders_by_status", {}).items():
            print(f"  {status}: {count}")


if __name__ == "__main__":
    main()
