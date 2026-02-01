#!/usr/bin/env python3
"""
Script para poblar la base de datos con datos de prueba completos.

Uso:
    python scripts/seed_test_data.py [--reset]

Opciones:
    --reset    Borra todos los datos existentes antes de poblar (¡CUIDADO!)
"""

import argparse
import os
import sys
from pathlib import Path

# Cargar variables de ambiente desde config/general.env
PROJECT_ROOT = Path(__file__).parent.parent
ENV_FILE = PROJECT_ROOT / "conf" / "general.env"
SECRETS_FILE = PROJECT_ROOT / "conf" / "secrets.env"


def load_env_file(env_path):
    """Cargar variables de ambiente desde un archivo .env"""
    if not env_path.exists():
        return

    with env_path.open() as f:
        for raw_line in f:
            line = raw_line.strip()
            # Ignorar comentarios y líneas vacías
            if not line or line.startswith("#"):
                continue
            # Parsear KEY=VALUE
            if "=" in line:
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip()
                # No sobrescribir si ya está definida
                if key not in os.environ:
                    os.environ[key] = value


# Cargar archivos de configuración
load_env_file(ENV_FILE)
if SECRETS_FILE.exists():
    load_env_file(SECRETS_FILE)

# Agregar el directorio build al path para importar los módulos
sys.path.insert(0, str(PROJECT_ROOT / "build"))

from sqlalchemy import func, select, text  # noqa: E402

from shared.config import load_config  # noqa: E402
from shared.db import get_session, init_db, init_engine  # noqa: E402
from shared.models import (  # noqa: E402
    Base,
    Customer,
    DiningSession,
    Employee,
    MenuCategory,
    MenuItem,
    Modifier,
    ModifierGroup,
    Order,
    OrderItem,
    OrderItemModifier,
)
from shared.services.seed import load_seed_data  # noqa: E402


def reset_database():
    """Borra todos los datos de las tablas (¡CUIDADO!)"""
    print("⚠️  ADVERTENCIA: Borrando todos los datos...")
    with get_session() as session:
        # Orden inverso para respetar las foreign keys
        session.execute(text("DELETE FROM order_item_modifiers"))
        session.execute(text("DELETE FROM order_items"))
        session.execute(text("DELETE FROM order_status_history"))
        session.execute(text("DELETE FROM orders"))
        session.execute(text("DELETE FROM dining_sessions"))
        session.execute(text("DELETE FROM menu_item_modifier_groups"))
        session.execute(text("DELETE FROM modifiers"))
        session.execute(text("DELETE FROM modifier_groups"))
        session.execute(text("DELETE FROM menu_items"))
        session.execute(text("DELETE FROM menu_categories"))
        session.execute(text("DELETE FROM employee_route_access"))
        session.execute(text("DELETE FROM employees"))
        session.execute(text("DELETE FROM customers"))
        session.execute(text("DELETE FROM route_permissions"))
        session.execute(text("DELETE FROM notifications"))
        session.execute(text("DELETE FROM promotions"))
        session.execute(text("DELETE FROM discount_codes"))
        session.commit()
    print("✅ Base de datos limpia")


def seed_basic_data():
    """Ejecuta el seed básico del sistema"""
    print("📦 Poblando datos básicos (categorías, items, empleados)...")
    with get_session() as session:
        load_seed_data(session)
        session.commit()
    print("✅ Datos básicos poblados")


def seed_additional_customers():
    """Crea clientes adicionales para pruebas"""
    print("👥 Creando clientes adicionales...")

    customers_data = [
        {"name": "María García", "email": "maria.garcia@example.com", "phone": "+34611222333"},
        {"name": "Juan Pérez", "email": "juan.perez@example.com", "phone": "+34622333444"},
        {"name": "Ana López", "email": "ana.lopez@example.com", "phone": "+34633444555"},
        {
            "name": "Carlos Rodríguez",
            "email": "carlos.rodriguez@example.com",
            "phone": "+34644555666",
        },
        {"name": "Laura Martínez", "email": "laura.martinez@example.com", "phone": "+34655666777"},
        {"name": "Pedro Sánchez", "email": "pedro.sanchez@example.com", "phone": "+34666777888"},
        {
            "name": "Sofia Fernández",
            "email": "sofia.fernandez@example.com",
            "phone": "+34677888999",
        },
        {"name": "Miguel Torres", "email": "miguel.torres@example.com", "phone": "+34688999000"},
    ]

    with get_session() as session:
        for customer_data in customers_data:
            customer = Customer()
            customer.name = customer_data["name"]
            customer.email = customer_data["email"]
            customer.phone = customer_data["phone"]
            session.add(customer)
        session.commit()

    print(f"✅ {len(customers_data)} clientes adicionales creados")


def seed_test_orders():
    """Crea órdenes de prueba con diferentes estados"""
    print("🍔 Creando órdenes de prueba...")
    with get_session() as session:
        # Obtener datos necesarios
        customers = session.execute(select(Customer)).scalars().all()
        menu_items = session.execute(select(MenuItem)).scalars().all()

        # Obtener grupos de modificadores obligatorios
        modifier_groups = session.execute(select(ModifierGroup)).scalars().all()
        modifier_groups_by_name = {mg.name: mg for mg in modifier_groups}

        if not customers or not menu_items:
            print("⚠️  No hay clientes o items de menú. Ejecuta seed_basic_data primero.")
            return

        # Crear algunas mesas con órdenes
        mesas = ["1", "2", "3", "4", "5", "A", "B", "C"]

        for i, mesa in enumerate(mesas):
            customer = customers[i % len(customers)]

            # Crear sesión de comida (cuenta)
            dining_session = DiningSession(
                customer_id=customer.id,
                status="open",
                table_number=mesa,
                notes=f"Mesa {mesa} - Prueba",
            )
            session.add(dining_session)
            session.flush()

            # Crear 1-3 órdenes por mesa
            num_orders = (i % 3) + 1
            for j in range(num_orders):
                order = Order(
                    customer_id=customer.id,
                    session_id=dining_session.id,
                    workflow_status=[
                        "requested",
                        "waiter_accepted",
                        "kitchen_in_progress",
                        "ready_for_delivery",
                    ][j % 4],
                    payment_status="unpaid",
                    notes=f"Orden de prueba {j + 1} para mesa {mesa}",
                )

                # Agregar 1-4 items a cada orden
                num_items = ((i + j) % 4) + 1
                for k in range(num_items):
                    selected_menu_item = menu_items[(i * num_orders + j + k) % len(menu_items)]
                    order_item = OrderItem(
                        order=order,
                        menu_item_id=selected_menu_item.id,
                        quantity=(k % 3) + 1,
                        unit_price=selected_menu_item.price,
                        special_instructions="Sin cebolla" if k % 2 == 0 else None,
                    )
                    session.add(order_item)
                    session.flush()

                    # Agregar modificadores obligatorios según el tipo de producto
                    # Para Combos, agregar bebida y guarnición
                    if selected_menu_item.category.name == "Combos":
                        # Agregar bebida
                        bebida_group = modifier_groups_by_name.get("Elige tu Bebida")
                        if bebida_group and bebida_group.modifiers:
                            selected_bebida = bebida_group.modifiers[
                                k % len(bebida_group.modifiers)
                            ]
                            modifier_item = OrderItemModifier(
                                order_item=order_item,
                                modifier_id=selected_bebida.id,
                                quantity=1,
                                unit_price_adjustment=selected_bebida.price_adjustment,
                            )
                            session.add(modifier_item)

                        # Agregar guarnición
                        guarnicion_group = modifier_groups_by_name.get("Elige tu Guarnición")
                        if guarnicion_group and guarnicion_group.modifiers:
                            selected_guarnicion = guarnicion_group.modifiers[
                                (k + 1) % len(guarnicion_group.modifiers)
                            ]
                            modifier_item = OrderItemModifier(
                                order_item=order_item,
                                modifier_id=selected_guarnicion.id,
                                quantity=1,
                                unit_price_adjustment=selected_guarnicion.price_adjustment,
                            )
                            session.add(modifier_item)

                session.add(order)

            # Recalcular totales de la sesión
            session.flush()
            dining_session.recompute_totals()

        session.commit()

    print(f"✅ {len(mesas)} mesas con órdenes creadas")


def print_summary():
    """Imprime un resumen de los datos creados"""
    print("\n" + "=" * 60)
    print("📊 RESUMEN DE DATOS DE PRUEBA")
    print("=" * 60)
    with get_session() as session:
        counts = {
            "Categorías": session.execute(select(func.count(MenuCategory.id))).scalar(),
            "Items de Menú": session.execute(select(func.count(MenuItem.id))).scalar(),
            "Grupos de Modificadores": session.execute(
                select(func.count(ModifierGroup.id))
            ).scalar(),
            "Modificadores": session.execute(select(func.count(Modifier.id))).scalar(),
            "Clientes": session.execute(select(func.count(Customer.id))).scalar(),
            "Empleados": session.execute(select(func.count(Employee.id))).scalar(),
            "Sesiones (Mesas)": session.execute(select(func.count(DiningSession.id))).scalar(),
            "Órdenes": session.execute(select(func.count(Order.id))).scalar(),
        }

        for key, value in counts.items():
            print(f"  {key}: {value}")

    print("\n👤 USUARIOS DE PRUEBA (password: ChangeMe!123)")
    print("-" * 60)
    users = [
        ("Super Admin", "admin@cafeteria.test"),
        ("Admin Roles", "admin.roles@cafeteria.test"),
        ("Mesero 1", "juan.mesero@cafeteria.test"),
        ("Mesero 2", "maria.mesera@cafeteria.test"),
        ("Chef 1", "carlos.chef@cafeteria.test"),
        ("Chef 2", "ana.chef@cafeteria.test"),
        ("Cajero 1", "laura.cajera@cafeteria.test"),
    ]

    for name, email in users:
        print(f"  {name:20} {email}")

    print("\n🍔 CATEGORÍAS Y ADITAMENTOS")
    print("-" * 60)
    print("  • Combos, Hamburguesas, Pizzas, Tacos, Ensaladas")
    print("  • Bebidas (con tamaños), Postres")
    print("  • Queso Extra (4 tipos)")
    print("  • Salsas (7 tipos)")
    print("  • Proteínas Extra (4 tipos)")
    print("  • Vegetales (8 tipos)")
    print("  • Punto de cocción")

    print("\n" + "=" * 60)
    print("✨ ¡Listo para probar!")
    print("=" * 60 + "\n")


def main():
    """Función principal"""
    parser = argparse.ArgumentParser(description="Poblar base de datos con datos de prueba")
    parser.add_argument(
        "--reset", action="store_true", help="Borrar todos los datos antes de poblar"
    )
    args = parser.parse_args()

    print("\n🚀 SCRIPT DE POBLACIÓN DE DATOS DE PRUEBA")
    print("=" * 60 + "\n")

    # Mostrar configuración cargada
    print("📋 Configuración cargada desde config/general.env:")
    print(f"   Base de datos: {os.getenv('MYSQL_DATABASE', 'N/A')}")
    print(f"   Usuario: {os.getenv('MYSQL_USER', 'N/A')}")
    print(f"   Host: {os.getenv('MYSQL_HOST', 'localhost')}")
    print(f"   Puerto: {os.getenv('MYSQL_PORT', '3306')}")
    print(f"   Restaurante: {os.getenv('RESTAURANT_NAME', 'N/A')}")
    print(f"   Password default empleados: {os.getenv('SEED_EMPLOYEE_PASSWORD', 'ChangeMe!123')}")
    print("")

    # Inicializar base de datos/engine
    config = load_config("seed-script")
    init_engine(config)
    init_db(Base.metadata)

    if args.reset:
        confirm = input(
            "⚠️  ¿Estás seguro de borrar todos los datos? (escribe 'SI' para confirmar): "
        )
        if confirm == "SI":
            reset_database()
        else:
            print("❌ Operación cancelada")
            return

    # Poblar datos
    seed_basic_data()
    seed_additional_customers()
    seed_test_orders()

    # Mostrar resumen
    print_summary()


if __name__ == "__main__":
    main()
