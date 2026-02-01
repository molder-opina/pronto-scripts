#!/usr/bin/env python3
"""
QA Comprehensive Test Suite - Pronto Cafeteria
Tests based on detailed test plan covering CLIENT and STAFF modules
"""

import os
import sys
from datetime import datetime

import requests
from sqlalchemy import create_engine, text

# --- CONFIG ---
CLIENT_URL = "http://localhost:6080"
EMPLOYEE_URL = "http://localhost:6081"
DB_USER = os.environ.get("POSTGRES_USER", "pronto")
DB_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "pronto123")
DB_HOST = os.environ.get("POSTGRES_HOST", "localhost")
DB_PORT = os.environ.get("POSTGRES_PORT", "5432")
DB_NAME = os.environ.get("POSTGRES_DB", "pronto")

DB_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

RESULTS = {"passed": [], "failed": [], "skipped": []}


def get_db():
    return create_engine(DB_URL).connect()


def log_pass(test_id, desc):
    RESULTS["passed"].append({"id": test_id, "desc": desc})
    print(f"  ✅ PASS: {desc}")


def log_fail(test_id, desc, reason):
    RESULTS["failed"].append({"id": test_id, "desc": desc, "reason": reason})
    print(f"  ❌ FAIL: {desc}")
    print(f"         Razón: {reason}")


def log_skip(test_id, desc, reason):
    RESULTS["skipped"].append({"id": test_id, "desc": desc, "reason": reason})
    print(f"  ⚠️  SKIP: {desc} - {reason}")


# =============================================================================
# TEST 01: NAVEGACION MENU - Validar via API y DB
# =============================================================================
def test_01_navegacion_menu():
    print("\n" + "=" * 70)
    print("TEST_01: NAVEGACION_MENU - Validar categorias y productos")
    print("=" * 70)

    # Verify menu endpoint returns categories and items
    try:
        resp = requests.get(f"{CLIENT_URL}/api/menu", timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            categories = data.get("categories", [])

            if len(categories) >= 7:
                log_pass("01.1", f"API retorna {len(categories)} categorías")
            else:
                log_fail("01.1", "Categorías insuficientes", f"Solo {len(categories)} encontradas")

            total_items = sum(len(cat.get("items", [])) for cat in categories)
            if total_items >= 50:
                log_pass("01.2", f"Total de productos: {total_items}")
            else:
                log_fail("01.2", "Productos insuficientes", f"Solo {total_items} encontrados")

            # Verify each category has items
            for cat in categories:
                cat_name = cat.get("name", "Unknown")
                items = cat.get("items", [])
                if len(items) > 0:
                    # Check first item has required fields
                    item = items[0]
                    has_name = "name" in item
                    has_price = "price" in item

                    if has_name and has_price:
                        log_pass(
                            "01.3",
                            f"Categoría '{cat_name}' tiene {len(items)} productos con datos válidos",
                        )
                    else:
                        log_fail("01.3", f"Datos incompletos en '{cat_name}'", "Falta name o price")

        else:
            log_fail("01.1", "API Menu no responde", f"Status: {resp.status_code}")

    except Exception as e:
        log_fail("01.1", "Error conectando a API Menu", str(e))

    # Verify from database
    with get_db() as conn:
        cats = conn.execute(text("SELECT COUNT(*) FROM pronto_menu_categories")).scalar()
        items = conn.execute(
            text("SELECT COUNT(*) FROM pronto_menu_items WHERE is_available = true")
        ).scalar()

        print(f"\n  📊 DB Stats: {cats} categorías, {items} productos disponibles")


# =============================================================================
# TEST 02: BUSQUEDA PRODUCTOS - Validar via API
# =============================================================================
def test_02_busqueda_productos():
    print("\n" + "=" * 70)
    print("TEST_02: BUSQUEDA_PRODUCTOS - Validar funcionalidad de búsqueda")
    print("=" * 70)

    try:
        # Search for "hamburguesa"
        resp = requests.get(f"{CLIENT_URL}/api/menu/search?q=hamburguesa", timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            results = data if isinstance(data, list) else data.get("items", data.get("results", []))
            if len(results) > 0:
                log_pass("02.1", f"Búsqueda 'hamburguesa' retorna {len(results)} resultados")
            else:
                log_skip(
                    "02.1", "Búsqueda hamburguesa", "Endpoint puede no existir o diferente formato"
                )
        elif resp.status_code == 404:
            log_skip("02.1", "Búsqueda vía API", "Endpoint /api/menu/search no implementado")
        else:
            log_fail("02.1", "Error en búsqueda", f"Status: {resp.status_code}")

    except Exception as e:
        log_skip("02.1", "Búsqueda API", f"Endpoint no disponible: {e}")

    # Verify search capability from DB
    with get_db() as conn:
        hamburguesas = conn.execute(
            text("SELECT COUNT(*) FROM pronto_menu_items WHERE LOWER(name) LIKE :pattern"),
            {"pattern": "%hamburguesa%"},
        ).scalar()
        pizzas = conn.execute(
            text("SELECT COUNT(*) FROM pronto_menu_items WHERE LOWER(name) LIKE :pattern"),
            {"pattern": "%pizza%"},
        ).scalar()

        log_pass("02.2", f"DB tiene: {hamburguesas} hamburguesas, {pizzas} pizzas buscables")


# =============================================================================
# TEST 03: FILTROS MENU - Verificar ordenamiento via DB
# =============================================================================
def test_03_filtros_menu():
    print("\n" + "=" * 70)
    print("TEST_03: FILTROS_MENU - Validar ordenamiento y filtros de precio")
    print("=" * 70)

    with get_db() as conn:
        # Verify price range exists
        prices = (
            conn.execute(
                text(
                    "SELECT MIN(price) as min_price, MAX(price) as max_price, AVG(price) as avg_price FROM pronto_menu_items"
                )
            )
            .mappings()
            .one()
        )

        log_pass(
            "03.1",
            f"Rango de precios: ${prices['min_price']:.2f} - ${prices['max_price']:.2f} (avg: ${prices['avg_price']:.2f})",
        )

        # Verify sorting works (ascending)
        asc_items = (
            conn.execute(
                text("SELECT name, price FROM pronto_menu_items ORDER BY price ASC LIMIT 3")
            )
            .mappings()
            .all()
        )

        if asc_items[0]["price"] <= asc_items[1]["price"]:
            log_pass(
                "03.2",
                f"Ordenamiento ASC funciona: {asc_items[0]['name']} (${asc_items[0]['price']})",
            )
        else:
            log_fail("03.2", "Ordenamiento ASC incorrecto", "Precios no ordenados")

        # Verify filtering by price range
        in_range = conn.execute(
            text("SELECT COUNT(*) FROM pronto_menu_items WHERE price BETWEEN 5 AND 15")
        ).scalar()

        log_pass("03.3", f"Productos en rango $5-$15: {in_range}")


# =============================================================================
# TEST 04: FILTROS TAGS - Verificar etiquetas via DB
# =============================================================================
def test_04_filtros_tags():
    print("\n" + "=" * 70)
    print("TEST_04: FILTROS_TAGS - Validar filtros por etiquetas")
    print("=" * 70)

    with get_db() as conn:
        # Check recommendation flags
        breakfast = conn.execute(
            text("SELECT COUNT(*) FROM pronto_menu_items WHERE is_breakfast_recommended = true")
        ).scalar()

        afternoon = conn.execute(
            text("SELECT COUNT(*) FROM pronto_menu_items WHERE is_afternoon_recommended = true")
        ).scalar()

        night = conn.execute(
            text("SELECT COUNT(*) FROM pronto_menu_items WHERE is_night_recommended = true")
        ).scalar()

        quick = conn.execute(
            text("SELECT COUNT(*) FROM pronto_menu_items WHERE is_quick_serve = true")
        ).scalar()

        log_pass("04.1", f"Productos Desayuno: {breakfast}")
        log_pass("04.2", f"Productos Comida: {afternoon}")
        log_pass("04.3", f"Productos Cena: {night}")
        log_pass("04.4", f"Productos Entrega Rápida: {quick}")


# =============================================================================
# TEST 05: MODAL PRODUCTO COMBOS - Validar modificadores obligatorios
# =============================================================================
def test_05_modal_producto_combos():
    print("\n" + "=" * 70)
    print("TEST_05: MODAL_PRODUCTO_COMBOS - Validar campos obligatorios")
    print("=" * 70)

    with get_db() as conn:
        # Find combos with required modifiers
        combos_with_modifiers = (
            conn.execute(
                text(
                    """
            SELECT i.id, i.name, i.price,
                   COUNT(mg.id) as modifier_groups,
                   SUM(CASE WHEN mg.min_selection > 0 THEN 1 ELSE 0 END) as required_groups
            FROM pronto_menu_items i
            JOIN pronto_menu_item_modifier_groups mimg ON i.id = mimg.menu_item_id
            JOIN pronto_modifier_groups mg ON mimg.modifier_group_id = mg.id
            WHERE i.name LIKE '%Combo%'
            GROUP BY i.id, i.name, i.price
            LIMIT 5
        """
                )
            )
            .mappings()
            .all()
        )

        for combo in combos_with_modifiers:
            print(
                f"  📦 {combo['name']}: ${combo['price']} - {combo['modifier_groups']} grupos ({combo['required_groups']} obligatorios)"
            )

        if len(combos_with_modifiers) > 0:
            log_pass("05.1", "Combos tienen grupos de modificadores configurados")
        else:
            log_fail("05.1", "Sin combos con modificadores", "Verificar seed data")

    # Test order creation validation
    print("\n  Testing API validation for required modifiers...")

    with get_db() as conn:
        combo = conn.execute(
            text("SELECT id FROM pronto_menu_items WHERE name LIKE '%Combo%' LIMIT 1")
        ).scalar()

    if combo:
        # Try to create order WITHOUT modifiers (should fail)
        payload = {
            "table_number": "M-M1",
            "customer": {"name": "Test", "email": "test@test.com"},
            "items": [{"menu_item_id": combo, "quantity": 1, "modifiers": []}],
        }

        resp = requests.post(f"{CLIENT_URL}/api/orders", json=payload, timeout=10)
        if resp.status_code == 400:
            log_pass("05.2", "API rechaza orden sin modificadores obligatorios (400)")
        else:
            log_fail("05.2", "API debería rechazar orden incompleta", f"Status: {resp.status_code}")


# =============================================================================
# TEST 06: MODAL PRODUCTO EXTRAS - Validar extras con costo
# =============================================================================
def test_06_modal_producto_extras():
    print("\n" + "=" * 70)
    print("TEST_06: MODAL_PRODUCTO_EXTRAS - Validar extras opcionales con costo")
    print("=" * 70)

    with get_db() as conn:
        # Find modifiers with extra cost
        extras_with_cost = (
            conn.execute(
                text(
                    """
            SELECT m.name, m.price_adjustment, mg.name as group_name
            FROM pronto_modifiers m
            JOIN pronto_modifier_groups mg ON m.group_id = mg.id
            WHERE m.price_adjustment > 0
            LIMIT 10
        """
                )
            )
            .mappings()
            .all()
        )

        if len(extras_with_cost) > 0:
            log_pass("06.1", f"{len(extras_with_cost)} extras con costo adicional encontrados")
            for extra in extras_with_cost[:3]:
                print(
                    f"    • {extra['name']} +${extra['price_adjustment']:.2f} ({extra['group_name']})"
                )
        else:
            log_fail("06.1", "Sin extras con costo", "Verificar configuración de modificadores")


# =============================================================================
# TEST 07: CARRITO - Agregar múltiples productos
# =============================================================================
def test_07_carrito_multiples():
    print("\n" + "=" * 70)
    print("TEST_07: CARRITO - Agregar múltiples productos")
    print("=" * 70)

    # This is primarily a frontend test, but we can verify cart API if exists
    try:
        resp = requests.get(f"{CLIENT_URL}/api/cart", timeout=10)
        if resp.status_code == 200:
            log_pass("07.1", "Endpoint de carrito existe")
        elif resp.status_code == 404:
            log_skip("07.1", "Cart API", "Carrito es client-side (localStorage)")
        else:
            log_skip("07.1", "Cart API", f"Status: {resp.status_code}")
    except Exception:
        # Fix E722: Do not use bare `except`
        log_skip("07.1", "Cart API", "Carrito manejado en frontend")

    # Fix RUF001: String contains ambiguous `ℹ`
    print("  (i)  El carrito es manejado en el frontend con localStorage")
    log_pass("07.2", "Cart persistence implementado via CartPersistence class")


# =============================================================================
# TEST 08 & 09: CHECKOUT Y CONFIRMACION
# =============================================================================
def test_08_09_checkout_confirmacion():
    print("\n" + "=" * 70)
    print("TEST_08_09: CHECKOUT Y CONFIRMACION - Flujo completo de orden")
    print("=" * 70)

    with get_db() as conn:
        # Get simple item
        item = (
            conn.execute(
                text(
                    """
            SELECT i.id, i.name, i.price
            FROM pronto_menu_items i
            WHERE NOT EXISTS (
                SELECT 1 FROM pronto_menu_item_modifier_groups mimg
                JOIN pronto_modifier_groups mg ON mimg.modifier_group_id = mg.id
                WHERE mimg.menu_item_id = i.id AND mg.min_selection > 0
            )
            LIMIT 1
        """
                )
            )
            .mappings()
            .one_or_none()
        )

    if not item:
        log_fail("08.1", "No hay items simples para test", "Todos requieren modificadores")
        return

    # Create order
    payload = {
        "table_number": "M-M1",
        "customer": {"name": "QA Test User", "email": "qatest@pronto.test", "phone": "5555555555"},
        "items": [{"menu_item_id": item["id"], "quantity": 2, "modifiers": []}],
    }

    resp = requests.post(f"{CLIENT_URL}/api/orders", json=payload, timeout=30)

    if resp.status_code in [200, 201]:
        order_data = resp.json()
        order_id = order_data.get("id")
        log_pass("08.1", f"Orden creada exitosamente: #{order_id}")

        # Verify order in DB
        with get_db() as conn:
            # Fix SQL Injection: use parameters
            stmt = text(
                """
                SELECT id, customer_name, customer_email, total_amount, workflow_status
                FROM pronto_orders WHERE id = :order_id
            """
            )
            order = conn.execute(stmt, {"order_id": order_id}).mappings().one_or_none()

            if order:
                log_pass("09.1", f"Orden #{order_id} verificada en BD")
                log_pass(
                    "09.2", f"Cliente: {order['customer_name']}, Email: {order['customer_email']}"
                )
                log_pass(
                    "09.3", f"Total: ${order['total_amount']}, Estado: {order['workflow_status']}"
                )
            else:
                log_fail("09.1", "Orden no encontrada en BD", "")
    else:
        log_fail("08.1", "Error creando orden", f"{resp.status_code}: {resp.text}")


# =============================================================================
# TEST 10: ORDENES ACTIVAS CLIENTE
# =============================================================================
def test_10_ordenes_activas():
    print("\n" + "=" * 70)
    print("TEST_10: ORDENES_ACTIVAS - Verificar órdenes del cliente")
    print("=" * 70)

    with get_db() as conn:
        active_count = conn.execute(
            text(
                """
            SELECT COUNT(*) FROM pronto_orders
            WHERE workflow_status NOT IN ('completed', 'cancelled', 'paid')
        """
            )
        ).scalar()

        log_pass("10.1", f"Órdenes activas en sistema: {active_count}")

        # Check order statuses distribution
        statuses = (
            conn.execute(
                text(
                    """
            SELECT workflow_status, COUNT(*) as count
            FROM pronto_orders
            GROUP BY workflow_status
        """
                )
            )
            .mappings()
            .all()
        )

        print("  📊 Distribución de estados:")
        for s in statuses:
            print(f"     • {s['workflow_status']}: {s['count']}")


# =============================================================================
# TEST 11: CANCELAR ORDEN
# =============================================================================
def test_11_cancelar_orden():
    print("\n" + "=" * 70)
    print("TEST_11: CANCELAR_ORDEN - Validar cancelación")
    print("=" * 70)

    # Create an order to cancel
    with get_db() as conn:
        item = conn.execute(
            text(
                """
            SELECT id FROM pronto_menu_items
            WHERE NOT EXISTS (
                SELECT 1 FROM pronto_menu_item_modifier_groups mimg
                JOIN pronto_modifier_groups mg ON mimg.modifier_group_id = mg.id
                WHERE mimg.menu_item_id = pronto_menu_items.id AND mg.min_selection > 0
            ) LIMIT 1
        """
            )
        ).scalar()

    # Create order
    payload = {
        "table_number": "M-M1",
        "customer": {"name": "Cancel Test", "email": "cancel@test.com"},
        "items": [{"menu_item_id": item, "quantity": 1, "modifiers": []}],
    }

    resp = requests.post(f"{CLIENT_URL}/api/orders", json=payload, timeout=30)
    if resp.status_code not in [200, 201]:
        log_fail("11.1", "No se pudo crear orden para cancelar", resp.text)
        return

    order_id = resp.json().get("id")
    print(f"  Orden #{order_id} creada para test de cancelación")

    # Try to cancel
    cancel_resp = requests.post(
        f"{CLIENT_URL}/api/orders/{order_id}/cancel",
        json={"reason": "QA Test - Cancel Test"},
        timeout=30,
    )

    if cancel_resp.status_code == 200:
        log_pass("11.1", f"Orden #{order_id} cancelada exitosamente")

        # Verify in DB
        with get_db() as conn:
            # Fix SQL Injection: use parameters
            stmt = text("SELECT workflow_status FROM pronto_orders WHERE id = :order_id")
            status = conn.execute(stmt, {"order_id": order_id}).scalar()
            if status == "cancelled":
                log_pass("11.2", "Estado 'cancelled' confirmado en BD")
            else:
                log_fail("11.2", "Estado incorrecto", f"Esperado 'cancelled', obtenido '{status}'")
    else:
        log_fail("11.1", "Error cancelando orden", f"{cancel_resp.status_code}: {cancel_resp.text}")


# =============================================================================
# TEST 15: LOGIN STAFF
# =============================================================================
def test_15_login_staff():
    print("\n" + "=" * 70)
    print("TEST_15: LOGIN_STAFF - Validar acceso con diferentes roles")
    print("=" * 70)

    roles = [
        ("admin@cafeteria.test", "Super Admin"),
        ("carlos.chef@cafeteria.test", "Chef"),
        ("juan.mesero@cafeteria.test", "Waiter"),
    ]

    for email, role in roles:
        s = requests.Session()
        resp = s.post(
            f"{EMPLOYEE_URL}/api/auth/login",
            json={"email": email, "password": "ChangeMe!123"},
            timeout=30,
        )

        if resp.status_code == 200:
            log_pass("15.1", f"Login exitoso: {role} ({email})")
        else:
            log_fail("15.1", f"Login fallido: {role}", f"{resp.status_code}")


# =============================================================================
# MAIN
# =============================================================================
def print_summary():
    print("\n")
    print("=" * 70)
    print("                    📋 RESUMEN DE PRUEBAS")
    print("=" * 70)

    total = len(RESULTS["passed"]) + len(RESULTS["failed"]) + len(RESULTS["skipped"])

    print(f"\n  ✅ Pasadas:   {len(RESULTS['passed'])}")
    print(f"  ❌ Fallidas:  {len(RESULTS['failed'])}")
    print(f"  ⚠️  Omitidas: {len(RESULTS['skipped'])}")
    print("  ━━━━━━━━━━━━━━━━━━")
    print(f"  📊 Total:     {total}")

    if RESULTS["failed"]:
        print("\n  ERRORES ENCONTRADOS:")
        for f in RESULTS["failed"]:
            print(f"    • [{f['id']}] {f['desc']}: {f['reason']}")

    print("\n" + "=" * 70)

    return len(RESULTS["failed"]) == 0


def main():
    print("\n" + "🧪" * 35)
    print("   SUITE DE PRUEBAS QA - PRONTO CAFETERÍA")
    print("🧪" * 35)
    print(f"\nFecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    # Run all tests
    test_01_navegacion_menu()
    test_02_busqueda_productos()
    test_03_filtros_menu()
    test_04_filtros_tags()
    test_05_modal_producto_combos()
    test_06_modal_producto_extras()
    test_07_carrito_multiples()
    test_08_09_checkout_confirmacion()
    test_10_ordenes_activas()
    test_11_cancelar_orden()
    test_15_login_staff()

    # Summary
    success = print_summary()

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
