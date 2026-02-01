#!/usr/bin/env python3
"""
🧪 Pronto QA Scripts - Pruebas automáticas recurrentes

Este script proporciona comandos para ejecutar pruebas comunes de QA
para la aplicación Pronto Cafetería.

Uso:
    python scripts/qa/run_tests.py --all          # Ejecutar todas las pruebas
    python scripts/qa/run_tests.py --login        # Probar login de empleados
    python scripts/qa/run_tests.py --order        # Probar flujo de órdenes
    python scripts/qa/run_tests.py --menu         # Verificar menú
    python scripts/qa/run_tests.py --health       # Health check de servicios
"""

import argparse
import os
import sys
from datetime import datetime

import requests

# --- CONFIG ---
CLIENT_URL = os.getenv("CLIENT_URL", "http://localhost:6080")
EMPLOYEE_URL = os.getenv("EMPLOYEE_URL", "http://localhost:6081")
API_URL = os.getenv("API_URL", "http://localhost:6082")

# Default credentials
DEFAULT_PASSWORD = "ChangeMe!123"
TEST_EMPLOYEES = {
    "admin": "admin@cafeteria.test",
    "waiter": "juan.mesero@cafeteria.test",
    "chef": "carlos.chef@cafeteria.test",
    "cashier": "luis.cajero@cafeteria.test",
}


def print_header(title):
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}\n")


def print_result(test_name, passed, details=""):
    icon = "✅" if passed else "❌"
    print(f"  {icon} {test_name}")
    if details:
        print(f"     → {details}")


# =============================================================================
# HEALTH CHECK
# =============================================================================
def test_health():
    print_header("🏥 HEALTH CHECK - Servicios")

    services = [
        ("Client App", f"{CLIENT_URL}/", 200),
        ("Employee App", f"{EMPLOYEE_URL}/", [200, 302]),
        ("API", f"{API_URL}/health", 200),
    ]

    all_passed = True
    for name, url, expected in services:
        try:
            resp = requests.get(url, timeout=10, allow_redirects=False)
            if isinstance(expected, list):
                passed = resp.status_code in expected
            else:
                passed = resp.status_code == expected
            print_result(name, passed, f"Status: {resp.status_code}")
            if not passed:
                all_passed = False
        except Exception as e:
            print_result(name, False, f"Error: {e}")
            all_passed = False

    return all_passed


# =============================================================================
# LOGIN TEST
# =============================================================================
def test_login():
    print_header("🔐 LOGIN TEST - Empleados")

    all_passed = True
    for role, email in TEST_EMPLOYEES.items():
        try:
            resp = requests.post(
                f"{EMPLOYEE_URL}/api/auth/login",
                json={"email": email, "password": DEFAULT_PASSWORD},
                timeout=10,
            )
            if resp.status_code == 200:
                data = resp.json()
                if data.get("status") == "success":
                    emp = data.get("data", {}).get("employee", {})
                    print_result(
                        f"Login {role}", True, f"ID: {emp.get('id')}, Role: {emp.get('role')}"
                    )
                else:
                    print_result(f"Login {role}", False, data.get("error", "Unknown error"))
                    all_passed = False
            else:
                print_result(f"Login {role}", False, f"Status: {resp.status_code}")
                all_passed = False
        except Exception as e:
            print_result(f"Login {role}", False, str(e))
            all_passed = False

    return all_passed


# =============================================================================
# MENU TEST
# =============================================================================
def test_menu():
    print_header("🍽️ MENU TEST - Categorías y Productos")

    try:
        resp = requests.get(f"{CLIENT_URL}/api/menu", timeout=10)
        if resp.status_code != 200:
            print_result("Obtener menú", False, f"Status: {resp.status_code}")
            return False

        data = resp.json()
        categories = data.get("categories", [])

        print_result("Obtener menú", True, f"{len(categories)} categorías")

        # Verify no Debug category
        debug_found = any(cat["name"].lower() == "debug" for cat in categories)
        print_result("Sin categoría Debug", not debug_found)

        # Count products
        total_items = sum(len(cat.get("items", [])) for cat in categories)
        print_result("Productos disponibles", total_items > 50, f"{total_items} productos")

        # List categories
        print("\n  Categorías encontradas:")
        for cat in categories:
            print(f"    • {cat['name']}: {len(cat.get('items', []))} items")

        return not debug_found and total_items > 50

    except Exception as e:
        print_result("Obtener menú", False, str(e))
        return False


# =============================================================================
# ORDER FLOW TEST
# =============================================================================
def test_order_flow():
    print_header("📝 ORDER FLOW - Ciclo completo")

    try:
        # 1. Get menu item without required modifiers
        resp = requests.get(f"{CLIENT_URL}/api/menu", timeout=10)
        data = resp.json()

        simple_item = None
        for cat in data.get("categories", []):
            for item in cat.get("items", []):
                modifiers = item.get("modifier_groups", [])
                required = [m for m in modifiers if m.get("min_selection", 0) > 0]
                if not required:
                    simple_item = item
                    break
            if simple_item:
                break

        if not simple_item:
            print_result(
                "Encontrar item simple", False, "No hay items sin modificadores obligatorios"
            )
            return False

        print_result("Encontrar item simple", True, simple_item["name"])

        # 2. Create order
        order_payload = {
            "table_number": "M-M01",
            "customer": {"name": "QA Test", "email": "qa@test.com"},
            "items": [{"menu_item_id": simple_item["id"], "quantity": 1, "modifiers": []}],
        }

        resp = requests.post(f"{CLIENT_URL}/api/orders", json=order_payload, timeout=30)
        if resp.status_code not in [200, 201]:
            print_result("Crear orden", False, f"Status: {resp.status_code}")
            return False

        order_data = resp.json()
        order_id = order_data.get("id")
        print_result("Crear orden", True, f"Orden #{order_id}")

        # 3. Chef login
        s = requests.Session()
        login_resp = s.post(
            f"{EMPLOYEE_URL}/api/auth/login",
            json={"email": TEST_EMPLOYEES["chef"], "password": DEFAULT_PASSWORD},
            timeout=10,
        )

        if login_resp.status_code != 200:
            print_result("Chef login", False)
            return False

        chef_data = login_resp.json()
        chef_id = chef_data.get("data", {}).get("employee", {}).get("id")
        print_result("Chef login", True, f"ID: {chef_id}")

        # 4. Start kitchen
        resp = s.post(
            f"{EMPLOYEE_URL}/api/orders/{order_id}/kitchen/start",
            json={"employee_id": chef_id},
            timeout=10,
        )
        print_result("Iniciar preparación", resp.status_code == 200)

        # 5. Complete kitchen
        resp = s.post(
            f"{EMPLOYEE_URL}/api/orders/{order_id}/kitchen/ready",
            json={"employee_id": chef_id},
            timeout=10,
        )
        print_result("Marcar listo", resp.status_code == 200)

        # 6. Waiter login
        s2 = requests.Session()
        login_resp = s2.post(
            f"{EMPLOYEE_URL}/api/auth/login",
            json={"email": TEST_EMPLOYEES["waiter"], "password": DEFAULT_PASSWORD},
            timeout=10,
        )

        waiter_data = login_resp.json()
        waiter_id = waiter_data.get("data", {}).get("employee", {}).get("id")
        print_result("Mesero login", login_resp.status_code == 200, f"ID: {waiter_id}")

        # 7. Deliver
        resp = s2.post(
            f"{EMPLOYEE_URL}/api/orders/{order_id}/deliver",
            json={"employee_id": waiter_id},
            timeout=10,
        )
        print_result("Entregar orden", resp.status_code == 200)

        print(f"\n  ✅ Flujo completado hasta entrega. Orden #{order_id}")
        return True

    except Exception as e:
        print_result("Order flow", False, str(e))
        return False


# =============================================================================
# MAIN
# =============================================================================
def main():
    parser = argparse.ArgumentParser(description="Pronto QA Test Runner")
    parser.add_argument("--all", action="store_true", help="Run all tests")
    parser.add_argument("--health", action="store_true", help="Health check")
    parser.add_argument("--login", action="store_true", help="Test employee login")
    parser.add_argument("--menu", action="store_true", help="Test menu API")
    parser.add_argument("--order", action="store_true", help="Test order flow")

    args = parser.parse_args()

    # Default to all if no specific test selected
    run_all = args.all or not any([args.health, args.login, args.menu, args.order])

    print("\n" + "🧪" * 30)
    print("   PRONTO QA TEST SUITE")
    print("🧪" * 30)
    print(f"\nFecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Client: {CLIENT_URL}")
    print(f"Employee: {EMPLOYEE_URL}")

    results = {}

    if run_all or args.health:
        results["health"] = test_health()

    if run_all or args.login:
        results["login"] = test_login()

    if run_all or args.menu:
        results["menu"] = test_menu()

    if run_all or args.order:
        results["order"] = test_order_flow()

    # Summary
    print_header("📊 RESUMEN")

    passed = sum(1 for v in results.values() if v)
    total = len(results)

    for test, result in results.items():
        print_result(test.upper(), result)

    print(f"\n  Total: {passed}/{total} tests pasaron")

    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
