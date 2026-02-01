#!/usr/bin/env python3
"""
Script maestro para poblar la base de datos con todos los datos de seed.
Basado en los modelos ORM actuales de models.py

Uso:
    python seeds/seed_all.py              # Seed completo
    python seeds/seed_all.py --reset      # Borra todo y vuelve a seedear
"""

import argparse
import os
import sys
from pathlib import Path
from decimal import Decimal

sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent.parent / "build"))
sys.path.insert(0, "/Users/molder/projects/github - molder/pronto/pronto-app/src")

from sqlalchemy import select, text, func

from shared.config import load_config
from shared.db import get_session, init_db, init_engine
from shared.models import (
    Area,
    Base,
    BusinessConfig,
    BusinessInfo,
    BusinessSchedule,
    Customer,
    DayPeriod,
    DiningSession,
    Employee,
    Feedback,
    FeedbackQuestion,
    KeyboardShortcut,
    MenuCategory,
    MenuItem,
    MenuItemDayPeriod,
    MenuItemModifierGroup,
    Modifier,
    ModifierGroup,
    Notification,
    Order,
    OrderItem,
    OrderItemModifier,
    OrderStatusHistory,
    OrderStatusLabel,
    ProductSchedule,
    RoutePermission,
    SplitBill,
    SplitBillAssignment,
    SplitBillPerson,
    Table,
    WaiterCall,
    WaiterTableAssignment,
)
from shared.security import hash_credentials, hash_identifier
from shared.validation import validate_password


def load_env():
    project_root = Path(__file__).parent.parent
    for env_file in ["config/general.env", "config/secrets.env"]:
        env_path = project_root / env_file
        if env_path.exists():
            with open(env_path) as f:
                for line in f:
                    line = line.strip()
                    if line and "=" in line and not line.startswith("#"):
                        key, value = line.split("=", 1)
                        os.environ.setdefault(key.strip(), value.strip())


def init_database():
    load_env()
    config = load_config("seed_script")
    init_engine(config)
    init_db(Base.metadata)


def seed_areas(session):
    print("\n📍 Creando áreas...")
    areas_data = [
        ("Terraza", "Terraza exterior", "TZ", "#ff6b35"),
        ("Comedor Principal", "Área principal", "CM", "#4ecdc4"),
        ("Barra", "Área de barra", "BR", "#45b7d1"),
        ("Salón VIP", "Salón privado", "VP", "#9c27b0"),
        ("Jardín", "Jardín exterior", "JD", "#ffeead"),
    ]

    areas = []
    for name, desc, prefix, color in areas_data:
        existing = session.execute(
            select(Area).where(Area.name == name)
        ).scalar_one_or_none()
        if existing:
            areas.append(existing)
            continue
        area = Area(
            name=name, description=desc, prefix=prefix, color=color, is_active=True
        )
        session.add(area)
        session.flush()
        areas.append(area)

    print(f"   {len(areas)} áreas")
    return areas


def seed_tables(session, areas):
    print("\n🪑 Creando mesas...")
    tables_per_area = {
        "Terraza": ["T1", "T2", "T3", "T4", "T5"],
        "Comedor Principal": ["M1", "M2", "M3", "M4", "M5", "M6", "M7"],
        "Barra": ["B1", "B2", "B3", "B4"],
        "Salón VIP": ["V1", "V2"],
        "Jardín": ["J1", "J2", "J3"],
    }

    import hashlib, time

    tables = []
    for area in areas:
        area_prefix = area.prefix
        for table_num in tables_per_area.get(area.name, ["1"]):
            existing = session.execute(
                select(Table).where(Table.table_number == table_num)
            ).scalar_one_or_none()
            if existing:
                tables.append(existing)
                continue

            unique_str = f"{area.name}-{table_num}-{int(time.time())}"
            qr_code = hashlib.sha256(unique_str.encode()).hexdigest()[:32]

            table = Table(
                table_number=table_num,
                qr_code=qr_code,
                area_id=area.id,
                capacity=4,
                status="available",
                is_active=True,
            )
            session.add(table)
            session.flush()
            tables.append(table)

    print(f"   {len(tables)} mesas")
    return tables


def seed_day_periods(session):
    print("\n⏰ Creando períodos del día...")
    periods_data = [
        ("breakfast", "Desayuno", "06:00", "12:00", "☀️", "#FFD93D"),
        ("afternoon", "Tarde", "12:00", "18:00", "🌤️", "#6BCB77"),
        ("night", "Noche", "18:00", "23:59", "🌙", "#4D96FF"),
    ]

    periods = []
    for key, name, start, end, icon, color in periods_data:
        existing = session.execute(
            select(DayPeriod).where(DayPeriod.period_key == key)
        ).scalar_one_or_none()
        if existing:
            periods.append(existing)
            continue
        period = DayPeriod(
            period_key=key,
            name=name,
            start_time=start,
            end_time=end,
            icon=icon,
            color=color,
            display_order=0 if key == "breakfast" else 1 if key == "afternoon" else 2,
        )
        session.add(period)
        session.flush()
        periods.append(period)

    print(f"   {len(periods)} períodos")
    return periods


def seed_categories(session):
    print("\n📋 Creando categorías...")
    categories_data = [
        ("Combos", "Combos especiales", 1),
        ("Hamburguesas", "Hamburguesas gourmet", 2),
        ("Pizzas", "Pizzas artesanales", 3),
        ("Tacos", "Tacos mexicanos", 4),
        ("Ensaladas", "Frescas y saludables", 5),
        ("Bebidas", "Bebidas y licuados", 6),
        ("Postres", "Dulces y pasteles", 7),
        ("Extras", "Acompañamientos", 8),
    ]

    categories = {}
    for name, desc, order in categories_data:
        existing = session.execute(
            select(MenuCategory).where(MenuCategory.name == name)
        ).scalar_one_or_none()
        if existing:
            categories[name] = existing
            continue
        cat = MenuCategory(name=name, description=desc, display_order=order)
        session.add(cat)
        session.flush()
        categories[name] = cat

    print(f"   {len(categories)} categorías")
    return categories


def seed_menu_items(session, categories):
    print("\n🍔 Creando productos...")
    items_data = []

    combos = categories["Combos"]
    for name, desc, price in [
        ("Combo Familiar", "4 burgers, papas, bebidas", 29.99),
        ("Combo Pareja", "2 burgers, papas medianas", 18.99),
        ("Combo Individual", "1 burger, papas pequeñas", 10.99),
    ]:
        items_data.append((combos, name, desc, price, 25, True, False, False))

    burgers = categories["Hamburguesas"]
    for name, desc, price, prep in [
        ("Doble Queso", "Doble carne y queso", 9.50, 18),
        ("Clásica", "Lechuga, tomate, cebolla", 7.50, 15),
        ("BBQ Bacon", "Bacon, cheddar, salsa BBQ", 10.50, 18),
        ("Vegetariana", "Medallón de garbanzos", 8.50, 16),
        ("Mexicana", "Jalapeños, guacamole", 11.50, 19),
    ]:
        items_data.append((burgers, name, desc, price, prep, False, False, False))

    drinks = categories["Bebidas"]
    for name, desc, price in [
        ("Coca-Cola", "500ml", 2.50),
        ("Agua Mineral", "500ml", 1.50),
        ("Limonada", "Natural", 3.00),
        ("Café Americano", "Caliente", 2.00),
        ("Smoothie", "Frutas tropicales", 4.50),
    ]:
        items_data.append((drinks, name, desc, price, 5, False, False, False))

    count = 0
    for category, name, desc, price, prep, breakfast, afternoon, night in items_data:
        existing = session.execute(
            select(MenuItem).where(
                MenuItem.name == name, MenuItem.category_id == category.id
            )
        ).scalar_one_or_none()
        if existing:
            continue
        item = MenuItem(
            name=name,
            description=desc,
            price=price,
            category_id=category.id,
            preparation_time_minutes=prep,
            is_breakfast_recommended=breakfast,
            is_afternoon_recommended=afternoon,
            is_night_recommended=night,
            is_available=True,
            is_quick_serve=price < 5.0,
        )
        session.add(item)
        count += 1

    print(f"   {count} productos")
    return count


def seed_modifier_groups(session):
    print("\n🔧 Creando grupos de modificadores...")
    groups_data = [
        ("Queso Extra", "Agrega queso", 0, 3, False),
        ("Salsas", "Elige salsas", 0, 3, False),
        ("Proteínas", "Proteína extra", 0, 2, False),
        ("Vegetales", "Vegetales adicionales", 0, 5, False),
        ("Tamaño", "Tamaño de porción", 1, 1, True),
    ]

    groups = {}
    for name, desc, min_sel, max_sel, required in groups_data:
        existing = session.execute(
            select(ModifierGroup).where(ModifierGroup.name == name)
        ).scalar_one_or_none()
        if existing:
            groups[name] = existing
            continue
        group = ModifierGroup(
            name=name,
            description=desc,
            min_selection=min_sel,
            max_selection=max_sel,
            is_required=required,
        )
        session.add(group)
        session.flush()
        groups[name] = group

    print(f"   {len(groups)} grupos")
    return groups


def seed_modifiers(session, groups):
    print("\n➕ Creando modificadores...")
    modifiers_data = [
        (
            "Queso Extra",
            [
                ("Cheddar", 1.50),
                ("Mozzarella", 1.50),
                ("Azul", 2.00),
            ],
        ),
        (
            "Salsas",
            [
                ("BBQ", 0.50),
                ("Ranch", 0.50),
                ("Picante", 0.50),
            ],
        ),
        (
            "Proteínas",
            [
                ("Carne Extra", 3.00),
                ("Pollo Extra", 2.50),
                ("Bacon", 2.00),
            ],
        ),
        (
            "Vegetales",
            [
                ("Lechuga", 0.00),
                ("Tomate", 0.00),
                ("Aguacate", 1.50),
            ],
        ),
        (
            "Tamaño",
            [
                ("Chica", 0.00),
                ("Mediana", 1.50),
                ("Grande", 2.50),
            ],
        ),
    ]

    count = 0
    for group_name, modifiers in modifiers_data:
        group = groups.get(group_name)
        if not group:
            continue
        for name, price in modifiers:
            existing = session.execute(
                select(Modifier).where(
                    Modifier.name == name, Modifier.group_id == group.id
                )
            ).scalar_one_or_none()
            if existing:
                continue
            mod = Modifier(group_id=group.id, name=name, price_adjustment=price)
            session.add(mod)
            count += 1

    print(f"   {count} modificadores")
    return count


def seed_employees(session):
    print("\n👥 Creando empleados...")
    password = get_default_password()
    validate_password(password)

    employees_data = [
        ("Admin General", "admin@cafeteria.test", "super_admin"),
        ("Admin de Roles", "admin.roles@cafeteria.test", "admin"),
        ("Mesero 1", "juan.mesero@cafeteria.test", "waiter"),
        ("Mesero 2", "maria.mesera@cafeteria.test", "waiter"),
        ("Chef 1", "carlos.chef@cafeteria.test", "chef"),
        ("Chef 2", "ana.chef@cafeteria.test", "chef"),
        ("Cajero 1", "laura.cajera@cafeteria.test", "cashier"),
    ]

    count = 0
    for name, email, role in employees_data:
        email_hash = hash_identifier(email)
        existing = session.execute(
            select(Employee).where(Employee.email_hash == email_hash)
        ).scalar_one_or_none()
        if existing:
            continue

        scopes = {
            "super_admin": ["system", "admin", "waiter", "chef", "cashier"],
            "admin": ["admin", "waiter", "chef", "cashier"],
            "waiter": ["waiter", "cashier"],
            "chef": ["chef"],
            "cashier": ["cashier", "waiter"],
        }.get(role, [])

        emp = Employee(
            name=name,
            email=email,
            email_hash=email_hash,
            auth_hash=hash_credentials(email, password),
            role=role,
            allow_scopes=scopes,
            is_active=True,
        )
        if role == "waiter":
            emp.additional_roles = '["cashier"]'
        session.add(emp)
        count += 1

    print(f"   {count} empleados")
    return count


def seed_customers(session):
    print("\n👤 Creando clientes...")
    customers_data = [
        ("María García", "maria@email.com", "+34611111111"),
        ("Juan Pérez", "juan@email.com", "+34622222222"),
        ("Ana López", "ana@email.com", "+34633333333"),
        ("Carlos Rodríguez", "carlos@email.com", "+34644444444"),
    ]

    count = 0
    for name, email, phone in customers_data:
        email_hash = hash_identifier(email)
        existing = session.execute(
            select(Customer).where(Customer.email_hash == email_hash)
        ).scalar_one_or_none()
        if existing:
            continue
        cust = Customer(name=name, email=email, phone=phone)
        session.add(cust)
        count += 1

    print(f"   {count} clientes")
    return count


def seed_configs(session):
    print("\n⚙️ Creando configuraciones...")
    configs_data = [
        (
            "restaurant_name",
            "Pronto Café",
            "string",
            "general",
            "Nombre del Restaurante",
        ),
        ("currency_symbol", "$", "string", "general", "Símbolo de moneda"),
        ("tax_rate", 16.0, "float", "payments", "Tasa de Impuesto (%)"),
        ("enable_tips", True, "bool", "payments", "Habilitar Propinas"),
        ("items_per_page", 10, "int", "general", "Ítems por página"),
        ("timezone", "America/Mexico_City", "string", "general", "Zona horaria"),
    ]

    count = 0
    for key, value, vtype, category, display in configs_data:
        existing = session.execute(
            select(BusinessConfig).where(BusinessConfig.config_key == key)
        ).scalar_one_or_none()
        if existing:
            continue
        config = BusinessConfig(
            config_key=key,
            config_value=value,
            value_type=vtype,
            category=category,
            display_name=display,
        )
        session.add(config)
        count += 1

    print(f"   {count} configuraciones")
    return count


def seed_business_info(session):
    print("\n🏪 Creando información del negocio...")
    existing = session.execute(select(BusinessInfo).limit(1)).scalar_one_or_none()
    if existing:
        print("   Ya existe")
        return

    info = BusinessInfo(
        business_name="Pronto Café",
        address="Calle Principal 123",
        city="Ciudad de México",
        phone="+52 55 1234 5678",
        email="contacto@pronto.cafe",
        currency="MXN",
        timezone="America/Mexico_City",
    )
    session.add(info)
    print("   Info del negocio creada")


def seed_business_schedule(session):
    print("\n📅 Creando horario del negocio...")
    existing = session.execute(select(BusinessSchedule).limit(1)).scalar_one_or_none()
    if existing:
        print("   Ya existe")
        return

    for day in range(7):
        is_open = day < 5
        schedule = BusinessSchedule(
            day_of_week=day,
            is_open=is_open,
            open_time="08:00" if is_open else None,
            close_time="22:00" if is_open else None,
        )
        session.add(schedule)

    session.flush()
    print("   Horario creado")


def seed_waiter_assignments(session):
    print("\n🔄 Creando asignaciones mesero-mesa...")
    employees = (
        session.execute(select(Employee).where(Employee.role == "waiter"))
        .scalars()
        .all()
    )
    tables = session.execute(select(Table).limit(4)).scalars().all()

    count = 0
    for emp in employees:
        for table in tables[:2]:
            existing = session.execute(
                select(WaiterTableAssignment).where(
                    WaiterTableAssignment.waiter_id == emp.id,
                    WaiterTableAssignment.table_id == table.id,
                )
            ).scalar_one_or_none()
            if existing:
                continue
            assignment = WaiterTableAssignment(
                waiter_id=emp.id,
                table_id=table.id,
                is_active=True,
            )
            session.add(assignment)
            count += 1

    print(f"   {count} asignaciones")
    return count


def seed_status_labels(session):
    print("\n🏷️ Creando etiquetas de estado...")
    labels_data = [
        ("new", "Nueva Orden", "Nueva", "Orden recién creada"),
        ("queued", "En Cola", "En cola", "Esperando preparación"),
        ("preparing", "Preparando", "En preparación", "Chef trabajando"),
        ("ready", "Lista", "Lista", "Listo para entregar"),
        ("delivered", "Entregada", "Entregada", "Entregada al cliente"),
        ("awaiting_payment", "Pendiente Pago", "Esperando pago", "Esperando cobro"),
        ("paid", "Pagada", "Pagada", "Pago confirmado"),
        ("cancelled", "Cancelada", "Cancelada", "Orden cancelada"),
    ]

    count = 0
    for key, client, employee, desc in labels_data:
        existing = session.execute(
            select(OrderStatusLabel).where(OrderStatusLabel.status_key == key)
        ).scalar_one_or_none()
        if existing:
            continue
        label = OrderStatusLabel(
            status_key=key,
            client_label=client,
            employee_label=employee,
            admin_desc=desc,
        )
        session.add(label)
        count += 1

    print(f"   {count} etiquetas")
    return count


def seed_keyboard_shortcuts(session):
    print("\n⌨️ Creando atajos de teclado...")
    shortcuts_data = [
        ("f1", "Nueva orden", "orders", "createOrder", True, True, 1),
        ("f2", "Buscar producto", "menu", "focusSearch", True, True, 2),
        ("f5", "Refrescar", "general", "refreshPage", True, False, 3),
        ("escape", "Cerrar modal", "general", "closeModal", True, True, 4),
    ]

    count = 0
    for combo, desc, cat, callback, enabled, prevent, order in shortcuts_data:
        existing = session.execute(
            select(KeyboardShortcut).where(KeyboardShortcut.combo == combo)
        ).scalar_one_or_none()
        if existing:
            continue
        ks = KeyboardShortcut(
            combo=combo,
            description=desc,
            category=cat,
            callback_function=callback,
            is_enabled=enabled,
            prevent_default=prevent,
            sort_order=order,
        )
        session.add(ks)
        count += 1

    print(f"   {count} atajos")
    return count


def get_default_password():
    return os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")


def reset_database(session):
    print("\n🗑️ Reseteando base de datos...")
    tables = [
        "pronto_order_item_modifiers",
        "pronto_order_items",
        "pronto_order_status_history",
        "pronto_orders",
        "pronto_dining_sessions",
        "pronto_menu_item_day_periods",
        "pronto_menu_item_modifier_groups",
        "pronto_modifiers",
        "pronto_modifier_groups",
        "pronto_menu_items",
        "pronto_menu_categories",
        "pronto_product_schedules",
        "pronto_split_bill_assignments",
        "pronto_split_bill_people",
        "pronto_split_bills",
        "pronto_waiter_table_assignments",
        "pronto_table_transfer_requests",
        "pronto_waiter_calls",
        "pronto_notifications",
        "pronto_feedback",
        "pronto_feedback_tokens",
        "pronto_feedback_questions",
        "pronto_keyboard_shortcuts",
        "pronto_recommendation_change_log",
        "pronto_realtime_events",
        "pronto_employee_route_access",
        "pronto_route_permissions",
        "pronto_employee_preferences",
        "pronto_employees",
        "pronto_customers",
        "pronto_tables",
        "pronto_areas",
        "pronto_business_config",
        "pronto_business_info",
        "pronto_business_schedule",
        "pronto_order_status_labels",
        "pronto_order_modifications",
        "pronto_promotions",
        "pronto_discount_codes",
        "pronto_secrets",
        "pronto_support_tickets",
        "pronto_custom_roles",
        "pronto_role_permissions",
        "pronto_system_roles",
        "pronto_system_permissions",
        "pronto_role_permission_bindings",
    ]

    for table in tables:
        session.execute(text(f"DELETE FROM {table}"))
    session.commit()
    print("   Base de datos reseteada")


def print_summary(session):
    print("\n" + "=" * 60)
    print("📊 RESUMEN")
    print("=" * 60)

    tables_to_count = {
        "Áreas": "pronto_areas",
        "Mesas": "pronto_tables",
        "Empleados": "pronto_employees",
        "Clientes": "pronto_customers",
        "Categorías": "pronto_menu_categories",
        "Productos": "pronto_menu_items",
        "Grupos Modif.": "pronto_modifier_groups",
        "Modificadores": "pronto_modifiers",
        "Órdenes": "pronto_orders",
        "Sesiones": "pronto_dining_sessions",
    }

    for name, table in tables_to_count.items():
        try:
            count = session.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar()
            print(f"  {name}: {count}")
        except Exception:
            print(f"  {name}: N/A")

    print("\n👤 USUARIOS (password: ChangeMe!123)")
    print("-" * 60)
    users = [
        ("Super Admin", "admin@cafeteria.test"),
        ("Admin Roles", "admin.roles@cafeteria.test"),
        ("Mesero 1", "juan.mesero@cafeteria.test"),
        ("Chef 1", "carlos.chef@cafeteria.test"),
    ]
    for name, email in users:
        print(f"  {name:20} {email}")

    print("\n" + "=" * 60)
    print("✅ Seed completado!")
    print("=" * 60)


def main():
    parser = argparse.ArgumentParser(description="Seed completo de PRONTO")
    parser.add_argument(
        "--reset", action="store_true", help="Borrar datos antes de seedear"
    )
    args = parser.parse_args()

    print("\n🚀 SEMILLADO COMPLETO DE PRONTO")
    print("=" * 60)

    init_database()

    with get_session() as session:
        if args.reset:
            confirm = input("\n⚠️  ¿BORRAR TODOS LOS DATOS? (escribe 'SI'): ")
            if confirm != "SI":
                print("Cancelado.")
                return
            reset_database(session)

        seed_areas(session)
        areas = session.execute(select(Area)).scalars().all()

        seed_tables(session, areas)
        seed_day_periods(session)
        categories = seed_categories(session)
        seed_menu_items(session, categories)
        groups = seed_modifier_groups(session)
        seed_modifiers(session, groups)
        seed_employees(session)
        seed_customers(session)
        seed_configs(session)
        seed_business_info(session)
        seed_business_schedule(session)
        seed_waiter_assignments(session)
        seed_status_labels(session)
        seed_keyboard_shortcuts(session)

        session.commit()
        print_summary(session)


if __name__ == "__main__":
    main()
