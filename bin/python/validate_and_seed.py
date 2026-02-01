#!/usr/bin/env python3
"""
Validate and Seed Database Script
Verifica que la base de datos tenga todos los datos necesarios (seed data).
Si falta algo, lo crea automáticamente.
"""

import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "build"))

from sqlalchemy import func

from shared.db import get_session
from shared.models import (
    Area,
    BusinessConfig,
    DayPeriod,
    Employee,
    MenuCategory,
    MenuItem,
    MenuItemDayPeriod,
    Table,
)
from shared.security import hash_credentials, hash_identifier


class DatabaseValidator:
    """Validates and seeds database with required data"""

    def __init__(self):
        self.missing_data = []
        self.created_data = []
        self.errors = []

    def print_header(self, text: str):
        """Print section header"""
        print(f"\n{'=' * 80}")
        print(f"  {text}")
        print(f"{'=' * 80}")

    def print_status(self, item: str, exists: bool, count: int = 0):
        """Print validation status"""
        if exists:
            print(f"✅ {item}: {count} registros encontrados")
        else:
            print(f"❌ {item}: NO ENCONTRADO - Se creará")
            self.missing_data.append(item)

    def validate_employees(self, db) -> bool:
        """Validate employees exist"""
        count = db.query(Employee).count()
        exists = count > 0
        self.print_status("Empleados", exists, count)
        return exists

    def validate_categories(self, db) -> bool:
        """Validate categories exist"""
        count = db.query(MenuCategory).count()
        exists = count > 0
        self.print_status("Categorías", exists, count)
        return exists

    def validate_products(self, db) -> bool:
        """Validate products exist"""
        count = db.query(MenuItem).count()
        exists = count > 0
        self.print_status("Productos", exists, count)
        return exists

    def validate_areas(self, db) -> bool:
        """Validate areas exist"""
        count = db.query(Area).count()
        exists = count > 0
        self.print_status("Áreas", exists, count)
        return exists

    def validate_tables(self, db) -> bool:
        """Validate tables exist"""
        count = db.query(Table).count()
        exists = count > 0
        self.print_status("Mesas", exists, count)
        return exists

    def validate_business_config(self, db) -> bool:
        """Validate business config exists"""
        count = db.query(BusinessConfig).count()
        exists = count > 0
        self.print_status("Configuración de Negocio", exists, count)
        return exists

    def validate_day_periods(self, db) -> bool:
        """Validate day periods exist"""
        count = db.query(DayPeriod).count()
        exists = count > 0
        self.print_status("Períodos del Día", exists, count)
        return exists

    def seed_employees(self, db):
        """Create default employees matching load_seed_data()"""
        print("\n🌱 Creando empleados...")

        employees_data = [
            # Super Admin (system role)
            {
                "name": "Admin General",
                "email": "admin@cafeteria.test",
                "role": "system",
                "additional_roles": None,
            },
            # Admin Roles
            {
                "name": "Admin Roles",
                "email": "admin.roles@cafeteria.test",
                "role": "admin",
                "additional_roles": None,
            },
            # Meseros (3)
            {
                "name": "Juan",
                "email": "juan.mesero@cafeteria.test",
                "role": "waiter",
                "additional_roles": '["cashier"]',
            },
            {
                "name": "Maria",
                "email": "maria.mesera@cafeteria.test",
                "role": "waiter",
                "additional_roles": '["cashier"]',
            },
            {
                "name": "Pedro",
                "email": "pedro.mesero@cafeteria.test",
                "role": "waiter",
                "additional_roles": '["cashier"]',
            },
            # Chefs (2)
            {
                "name": "Carlos",
                "email": "carlos.chef@cafeteria.test",
                "role": "chef",
                "additional_roles": None,
            },
            {
                "name": "Ana",
                "email": "ana.chef@cafeteria.test",
                "role": "chef",
                "additional_roles": None,
            },
            # Cajeros (2)
            {
                "name": "Laura",
                "email": "laura.cajera@cafeteria.test",
                "role": "cashier",
                "additional_roles": None,
            },
            {
                "name": "Roberto",
                "email": "roberto.cajero@cafeteria.test",
                "role": "cashier",
                "additional_roles": None,
            },
            # Content Manager
            {
                "name": "Sofia",
                "email": "sofia.contenido@cafeteria.test",
                "role": "content_manager",
                "additional_roles": None,
            },
        ]

        password = "ChangeMe!123"

        for emp_data in employees_data:
            email = emp_data["email"]
            email_hash = hash_identifier(email)

            # Check if employee already exists by email_hash
            existing = db.query(Employee).filter(Employee.email_hash == email_hash).first()
            if existing:
                # Update existing employee
                existing.name = emp_data["name"]
                existing.role = emp_data["role"]
                existing.additional_roles = emp_data["additional_roles"]
                print(f"  ⏭️  {emp_data['name']} ya existe (actualizado)")
                continue

            employee = Employee(
                name=emp_data["name"],
                email=email,
                email_hash=email_hash,
                auth_hash=hash_credentials(email, password),
                role=emp_data["role"],
                additional_roles=emp_data["additional_roles"],
                is_active=True,
            )
            db.add(employee)
            print(f"  ✅ Creado: {emp_data['name']} ({email})")
            self.created_data.append(f"Employee: {emp_data['name']}")

        db.commit()

    def seed_categories(self, db):
        """Create default categories matching load_seed_data()"""
        print("\n🌱 Creando categorías...")

        categories_data = [
            {"name": "Combos", "description": "Combos listos para disfrutar", "display_order": 1},
            {
                "name": "Hamburguesas",
                "description": "Opciones clásicas y gourmet",
                "display_order": 2,
            },
            {"name": "Pizzas", "description": "Pizzas artesanales", "display_order": 3},
            {"name": "Tacos", "description": "Tacos mexicanos auténticos", "display_order": 4},
            {"name": "Ensaladas", "description": "Frescas y saludables", "display_order": 5},
            {"name": "Bebidas", "description": "Bebidas frías y calientes", "display_order": 6},
            {"name": "Postres", "description": "Cierra con algo dulce", "display_order": 7},
            {"name": "Desayunos", "description": "Comienza el día con energía", "display_order": 8},
            {"name": "Botanas", "description": "Aperitivos para compartir", "display_order": 9},
            {
                "name": "Antojitos Mexicanos",
                "description": "Lo mejor de México",
                "display_order": 10,
            },
            {
                "name": "Sopas",
                "description": "Sopas calientes y reconfortantes",
                "display_order": 11,
            },
            {
                "name": "Especialidades",
                "description": "Platillos especiales de la casa",
                "display_order": 12,
            },
        ]

        for cat_data in categories_data:
            existing = db.query(MenuCategory).filter(MenuCategory.name == cat_data["name"]).first()
            if existing:
                # Update existing
                existing.description = cat_data["description"]
                existing.display_order = cat_data["display_order"]
                print(f"  ⏭️  {cat_data['name']} ya existe (actualizada)")
                continue

            category = MenuCategory(**cat_data)
            db.add(category)
            print(f"  ✅ Creada: {cat_data['name']}")
            self.created_data.append(f"Category: {cat_data['name']}")

        db.commit()

    def seed_products(self, db):
        """Create default products"""
        print("\n🌱 Creando productos...")

        # Get categories
        combos = db.query(MenuCategory).filter(MenuCategory.name == "Combos").first()
        hamburguesas = db.query(MenuCategory).filter(MenuCategory.name == "Hamburguesas").first()
        bebidas = db.query(MenuCategory).filter(MenuCategory.name == "Bebidas").first()

        if not all([combos, hamburguesas, bebidas]):
            print("  ⚠️  Categorías no encontradas, creándolas primero...")
            self.seed_categories(db)
            combos = db.query(MenuCategory).filter(MenuCategory.name == "Combos").first()
            hamburguesas = (
                db.query(MenuCategory).filter(MenuCategory.name == "Hamburguesas").first()
            )
            bebidas = db.query(MenuCategory).filter(MenuCategory.name == "Bebidas").first()

        products_data = [
            {
                "name": "Combo Familiar",
                "description": "4 hamburguesas + papas grandes + 4 bebidas",
                "price": 450.00,
                "category_id": combos.id,
                "is_available": True,
            },
            {
                "name": "Hamburguesa Simple",
                "description": "Carne, lechuga, tomate, cebolla",
                "price": 85.00,
                "category_id": hamburguesas.id,
                "is_available": True,
            },
            {
                "name": "Hamburguesa Doble",
                "description": "Doble carne, queso, tocino",
                "price": 120.00,
                "category_id": hamburguesas.id,
                "is_available": True,
            },
            {
                "name": "Limonada",
                "description": "Limonada natural 500ml",
                "price": 35.00,
                "category_id": bebidas.id,
                "is_available": True,
            },
            {
                "name": "Coca Cola",
                "description": "Coca Cola 600ml",
                "price": 30.00,
                "category_id": bebidas.id,
                "is_available": True,
            },
        ]

        for prod_data in products_data:
            existing = db.query(MenuItem).filter(MenuItem.name == prod_data["name"]).first()
            if existing:
                print(f"  ⏭️  {prod_data['name']} ya existe")
                continue

            product = MenuItem(**prod_data)
            db.add(product)
            print(f"  ✅ Creado: {prod_data['name']} (${prod_data['price']})")
            self.created_data.append(f"Product: {prod_data['name']}")

        db.commit()

    def seed_areas(self, db):
        """Create default areas"""
        print("\n🌱 Creando áreas...")

        areas_data = [
            {
                "name": "Terraza",
                "description": "Área exterior con vista",
                "prefix": "T",
                "color": "#10b981",
                "is_active": True,
            },
            {
                "name": "Salón Principal",
                "description": "Área interior principal",
                "prefix": "M",
                "color": "#ff6b35",
                "is_active": True,
            },
            {
                "name": "VIP",
                "description": "Área privada",
                "prefix": "V",
                "color": "#8b5cf6",
                "is_active": True,
            },
        ]

        for area_data in areas_data:
            existing = db.query(Area).filter(Area.name == area_data["name"]).first()
            if existing:
                # Update existing area fields
                existing.description = area_data["description"]
                existing.prefix = area_data["prefix"]
                existing.color = area_data["color"]
                print(f"  ⏭️  {area_data['name']} ya existe (actualizada)")
                continue

            area = Area(**area_data)
            db.add(area)
            print(f"  ✅ Creada: {area_data['name']}")
            self.created_data.append(f"Area: {area_data['name']}")

        db.commit()

    def seed_tables(self, db):
        """Create default tables"""
        print("\n🌱 Creando mesas...")

        # Get areas
        terraza = db.query(Area).filter(Area.name == "Terraza").first()
        salon = db.query(Area).filter(Area.name == "Salón Principal").first()
        vip = db.query(Area).filter(Area.name == "VIP").first()

        if not all([terraza, salon, vip]):
            print("  ⚠️  Áreas no encontradas, creándolas primero...")
            self.seed_areas(db)
            terraza = db.query(Area).filter(Area.name == "Terraza").first()
            salon = db.query(Area).filter(Area.name == "Salón Principal").first()
            vip = db.query(Area).filter(Area.name == "VIP").first()

        tables_data = [
            # Terraza (T1-T3)
            {
                "table_number": "T1",
                "capacity": 4,
                "area_id": terraza.id,
                "qr_code": "T1-QR-SEED",
                "status": "available",
                "is_active": True,
            },
            {
                "table_number": "T2",
                "capacity": 4,
                "area_id": terraza.id,
                "qr_code": "T2-QR-SEED",
                "status": "available",
                "is_active": True,
            },
            {
                "table_number": "T3",
                "capacity": 6,
                "area_id": terraza.id,
                "qr_code": "T3-QR-SEED",
                "status": "available",
                "is_active": True,
            },
            # Salón Principal (M1-M4)
            {
                "table_number": "M1",
                "capacity": 2,
                "area_id": salon.id,
                "qr_code": "M1-QR-SEED",
                "status": "available",
                "is_active": True,
            },
            {
                "table_number": "M2",
                "capacity": 4,
                "area_id": salon.id,
                "qr_code": "M2-QR-SEED",
                "status": "available",
                "is_active": True,
            },
            {
                "table_number": "M3",
                "capacity": 4,
                "area_id": salon.id,
                "qr_code": "M3-QR-SEED",
                "status": "available",
                "is_active": True,
            },
            {
                "table_number": "M4",
                "capacity": 6,
                "area_id": salon.id,
                "qr_code": "M4-QR-SEED",
                "status": "available",
                "is_active": True,
            },
            # VIP (V1)
            {
                "table_number": "V1",
                "capacity": 8,
                "area_id": vip.id,
                "qr_code": "V1-QR-SEED",
                "status": "available",
                "is_active": True,
            },
        ]

        for table_data in tables_data:
            existing = (
                db.query(Table).filter(Table.table_number == table_data["table_number"]).first()
            )
            if existing:
                # Update existing table
                existing.capacity = table_data["capacity"]
                existing.area_id = table_data["area_id"]
                print(f"  ⏭️  Mesa {table_data['table_number']} ya existe (actualizada)")
                continue

            table = Table(**table_data)
            db.add(table)
            print(
                f"  ✅ Creada: Mesa {table_data['table_number']} ({table_data['capacity']} personas)"
            )
            self.created_data.append(f"Table: {table_data['table_number']}")

        db.commit()

    def seed_business_config(self, db):
        """Create default business configuration"""
        print("\n🌱 Creando configuración de negocio...")

        config_data = [
            {
                "config_key": "restaurant_name",
                "config_value": "Cafetería de Prueba",
                "value_type": "string",
                "display_name": "Nombre del Restaurante",
            },
            {
                "config_key": "currency_code",
                "config_value": "MXN",
                "value_type": "string",
                "display_name": "Código de Moneda",
            },
            {
                "config_key": "currency_symbol",
                "config_value": "$",
                "value_type": "string",
                "display_name": "Símbolo de Moneda",
            },
            {
                "config_key": "tax_rate",
                "config_value": "0.16",
                "value_type": "float",
                "display_name": "Tasa de Impuestos",
            },
            {
                "config_key": "service_charge_rate",
                "config_value": "0.10",
                "value_type": "float",
                "display_name": "Tasa de Servicio",
            },
            {
                "config_key": "table_base_prefix",
                "config_value": "M",
                "value_type": "string",
                "display_name": "Prefijo de Mesa",
            },
            {
                "config_key": "items_per_page",
                "config_value": "10",
                "value_type": "integer",
                "display_name": "Items por Página",
            },
            {
                "config_key": "paid_orders_window_minutes",
                "config_value": "30",
                "value_type": "integer",
                "display_name": "Ventana de Órdenes Pagadas",
            },
            {
                "config_key": "checkout_prompt_duration_seconds",
                "config_value": "5",
                "value_type": "integer",
                "display_name": "Duración del Prompt de Checkout",
            },
        ]

        for config in config_data:
            existing = (
                db.query(BusinessConfig)
                .filter(BusinessConfig.config_key == config["config_key"])
                .first()
            )
            if existing:
                print(f"  ⏭️  {config['config_key']} ya existe")
                continue

            business_config = BusinessConfig(**config)
            db.add(business_config)
            print(f"  ✅ Creado: {config['config_key']} = {config['config_value']}")
            self.created_data.append(f"Config: {config['config_key']}")

        db.commit()

    def seed_day_periods(self, db):
        """Create default day periods"""
        print("\n🌱 Creando períodos del día...")

        periods_data = [
            {
                "period_key": "breakfast",
                "name": "Desayuno",
                "start_time": "06:00",
                "end_time": "11:00",
                "display_order": 1,
            },
            {
                "period_key": "lunch",
                "name": "Comida",
                "start_time": "12:00",
                "end_time": "17:00",
                "display_order": 2,
            },
            {
                "period_key": "dinner",
                "name": "Cena",
                "start_time": "18:00",
                "end_time": "23:00",
                "display_order": 3,
            },
        ]

        for period_data in periods_data:
            existing = (
                db.query(DayPeriod)
                .filter(DayPeriod.period_key == period_data["period_key"])
                .first()
            )
            if existing:
                print(f"  ⏭️  {period_data['name']} ya existe")
                continue

            period = DayPeriod(**period_data)
            db.add(period)
            print(
                f"  ✅ Creado: {period_data['name']} ({period_data['start_time']} - {period_data['end_time']})"
            )
            self.created_data.append(f"DayPeriod: {period_data['name']}")

        db.commit()

    def run_validation(self):
        """Run complete validation and seeding"""
        self.print_header("VALIDACIÓN Y SEED DE BASE DE DATOS")

        try:
            # Initialize database engine
            from shared.config import load_config
            from shared.db import init_engine

            config = load_config("validate_seed")
            init_engine(config)

            with get_session() as db:
                # Validate all data
                self.print_header("1. VALIDANDO DATOS EXISTENTES")

                has_employees = self.validate_employees(db)
                has_categories = self.validate_categories(db)
                has_products = self.validate_products(db)
                has_areas = self.validate_areas(db)
                has_tables = self.validate_tables(db)
                has_config = self.validate_business_config(db)
                has_periods = self.validate_day_periods(db)

                # Seed missing data
                if self.missing_data:
                    self.print_header("2. CREANDO DATOS FALTANTES")

                    if not has_employees:
                        self.seed_employees(db)

                    if not has_categories:
                        self.seed_categories(db)

                    if not has_products:
                        self.seed_products(db)

                    if not has_areas:
                        self.seed_areas(db)

                    if not has_tables:
                        self.seed_tables(db)

                    if not has_config:
                        self.seed_business_config(db)

                    if not has_periods:
                        self.seed_day_periods(db)
                else:
                    print("\n✅ Todos los datos necesarios están presentes")

                # Print summary
                self.print_header("RESUMEN")

                if self.created_data:
                    print(f"\n✅ Datos creados: {len(self.created_data)}")
                    for item in self.created_data:
                        print(f"   - {item}")
                else:
                    print("\n✅ No fue necesario crear datos nuevos")

                if self.errors:
                    print(f"\n❌ Errores encontrados: {len(self.errors)}")
                    for error in self.errors:
                        print(f"   - {error}")
                    return 1

                print("\n" + "=" * 80)
                print("✅ VALIDACIÓN COMPLETADA EXITOSAMENTE")
                print("=" * 80)
                return 0

        except Exception as e:
            print(f"\n❌ ERROR CRÍTICO: {e}")
            import traceback

            traceback.print_exc()
            return 1


def main():
    """Main entry point"""
    validator = DatabaseValidator()
    exit_code = validator.run_validation()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
