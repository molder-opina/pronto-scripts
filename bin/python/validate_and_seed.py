#!/usr/bin/env python3
"""
Validate and Seed Database Script (BLINDADO - RBAC Unified)
Verifica que la base de datos tenga todos los datos necesarios (seed data).
Usa el canon SystemSetting y SystemRole para una autorización robusta.
"""

import os
import sys
import json
from decimal import Decimal

# Add parent directory to path to ensure pronto_shared is importable
try:
    import pronto_shared
except ImportError:
    # Look for it in common locations
    sys.path.insert(0, '/opt/pronto')
    try:
        import pronto_shared
    except ImportError:
        raise ImportError("pronto_shared package not found.")

from sqlalchemy import func, select
from pronto_shared.db import get_session
from pronto_shared.models import (
    Area,
    SystemSetting,
    DayPeriod,
    Employee,
    MenuCategory,
    MenuItem,
    Table,
    SystemRole,
    SystemPermission,
    RolePermissionBinding
)
from pronto_shared.security import hash_credentials, hash_identifier
from pronto_shared.permissions import Permission, ROLE_PERMISSIONS

# Mandatory configuration keys required by the system
MANDATORY_CONFIG_KEYS = [
    "restaurant_name",
    "currency_code",
    "currency_symbol",
    "tax_rate",
    "service_charge_rate",
    "table_base_prefix",
    "items_per_page",
    "paid_orders_window_minutes",
    "checkout_prompt_duration_seconds",
]

class DatabaseValidator:
    """Validates and seeds database with required data using SystemSetting and RBAC canon"""

    def __init__(self):
        self.missing_data = []
        self.created_data = []
        self.updated_data = []
        self.errors = []

    def print_header(self, text: str):
        print(f"\n{'=' * 80}")
        print(f"  {text}")
        print(f"{'=' * 80}")

    def print_status(self, item: str, exists: bool, count: int = 0):
        if exists:
            print(f"✅ {item}: {count} registros encontrados")
        else:
            print(f"❌ {item}: INCOMPLETO o FALTANTE - Se procesará")
            self.missing_data.append(item)

    def validate_business_config(self, db) -> bool:
        """Validate all mandatory keys exist in pronto_system_settings"""
        existing_keys = {
            s.config_key for s in db.query(SystemSetting.config_key).filter(SystemSetting.config_key.in_(MANDATORY_CONFIG_KEYS)).all()
        }
        missing = [k for k in MANDATORY_CONFIG_KEYS if k not in existing_keys]
        exists = len(missing) == 0
        self.print_status("Configuración (SystemSetting)", exists, len(existing_keys))
        return exists

    def validate_roles(self, db) -> bool:
        """Validate system roles exist"""
        count = db.query(SystemRole).count()
        exists = count >= 5 # admin, cashier, chef, waiter, system
        self.print_status("Roles de Sistema", exists, count)
        return exists

    def validate_permissions(self, db) -> bool:
        """Validate system permissions exist"""
        count = db.query(SystemPermission).count()
        exists = count >= len(Permission)
        self.print_status("Permisos de Sistema", exists, count)
        return exists

    def seed_business_config(self, db):
        """Idempotent UPSERT for business configuration"""
        print("\n🌱 Sincronizando configuración de negocio...")
        config_data = [
            {"key": "restaurant_name", "value": "Cafetería de Prueba", "type": "string"},
            {"key": "currency_code", "value": "MXN", "type": "string"},
            {"key": "currency_symbol", "value": "$", "type": "string"},
            {"key": "tax_rate", "value": "0.16", "type": "float"},
            {"key": "service_charge_rate", "value": "0.10", "type": "float"},
            {"key": "table_base_prefix", "value": "M", "type": "string"},
            {"key": "items_per_page", "value": "10", "type": "integer"},
            {"key": "paid_orders_window_minutes", "value": "30", "type": "integer"},
            {"key": "checkout_prompt_duration_seconds", "value": "5", "type": "integer"},
        ]
        for item in config_data:
            key = item["key"]
            value = str(item["value"])
            v_type = item["type"]
            existing = db.query(SystemSetting).filter(SystemSetting.config_key == key).first()
            if existing:
                if existing.config_value != value or existing.value_type != v_type:
                    existing.config_value = value
                    existing.value_type = v_type
                    self.updated_data.append(f"Config: {key}")
            else:
                setting = SystemSetting(config_key=key, config_value=value, value_type=v_type, category="general")
                db.add(setting)
                self.created_data.append(f"Config: {key}")
        db.commit()

    def seed_rbac(self, db):
        """Idempotent UPSERT for RBAC system"""
        print("\n🌱 Sincronizando Roles y Permisos (RBAC)...")
        
        # 1. Seed Permissions from Enum
        for perm in Permission:
            code = perm.value
            category = code.split(":")[0] if ":" in code else "general"
            existing = db.query(SystemPermission).filter(SystemPermission.code == code).first()
            if not existing:
                db.add(SystemPermission(code=code, category=category, description=f"Permiso para {code}"))
                self.created_data.append(f"Permission: {code}")
        db.flush()

        # 2. Seed Roles and Bindings from ROLE_PERMISSIONS map
        for role_name, perms in ROLE_PERMISSIONS.items():
            role = db.query(SystemRole).filter(SystemRole.name == role_name).first()
            if not role:
                role = SystemRole(name=role_name, display_name=role_name.capitalize(), is_custom=False)
                db.add(role)
                db.flush()
                self.created_data.append(f"Role: {role_name}")
            
            # Sync bindings
            current_bindings = {b.permission.code for b in role.permissions if b.permission}
            target_codes = {p.value for p in perms}
            
            # Add missing
            for code in target_codes:
                if code not in current_bindings:
                    perm = db.query(SystemPermission).filter(SystemPermission.code == code).first()
                    if perm:
                        db.add(RolePermissionBinding(role_id=role.id, permission_id=perm.id))
                        self.updated_data.append(f"Binding: {role_name} -> {code}")
        
        db.commit()

    # Stubs for other validations
    def validate_employees(self, db): return db.query(Employee).count() > 0
    def validate_categories(self, db): return db.query(MenuCategory).count() > 0
    def validate_products(self, db): return db.query(MenuItem).count() > 0
    def validate_areas(self, db): return db.query(Area).count() > 0
    def validate_tables(self, db): return db.query(Table).count() > 0
    def validate_day_periods(self, db): return db.query(DayPeriod).count() > 0

    def run_validation(self):
        self.print_header("VALIDACIÓN Y SEED DE BASE DE DATOS (RBAC UNIFICADO)")
        try:
            from pronto_shared.config import load_config
            from pronto_shared.db import init_engine
            config = load_config("validate_seed")
            init_engine(config)

            with get_session() as db:
                self.print_header("1. VALIDANDO DATOS")
                self.validate_employees(db)
                self.validate_roles(db)
                self.validate_permissions(db)
                self.validate_categories(db)
                self.validate_products(db)
                has_config = self.validate_business_config(db)
                self.validate_day_periods(db)

                self.print_header("2. PROCESANDO CAMBIOS")
                self.seed_business_config(db)
                self.seed_rbac(db)

                self.print_header("RESUMEN")
                print(f"✅ Creados: {len(self.created_data)}")
                print(f"🔄 Actualizados: {len(self.updated_data)}")
                return 0
        except Exception as e:
            print(f"\n❌ ERROR CRÍTICO: {e}")
            import traceback
            traceback.print_exc()
            return 1

if __name__ == "__main__":
    sys.exit(DatabaseValidator().run_validation())
