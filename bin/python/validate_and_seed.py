#!/usr/bin/env python3
"""
Validate and Seed Database Script (V6 Blindado - Contract Driven)
Verifica la integridad total de la base de datos basándose en el CONFIG_CONTRACT.
Implementa política de Cero Tolerancia a llaves legacy y UPPERCASE.
"""

import os
import sys
import re
import logging
from decimal import Decimal
from uuid import uuid4

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
log = logging.getLogger(__name__)

# Add parent directory to path to ensure pronto_shared is importable
try:
    import pronto_shared
except ImportError:
    # Look for it in common locations
    sys.path.insert(0, '/opt/pronto/build')
    sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../pronto-libs/src')))
    try:
        import pronto_shared
    except ImportError:
        raise ImportError("pronto_shared package not found. Path: " + str(sys.path))

from sqlalchemy import func, select, text
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
from pronto_shared.config_contract import (
    CONFIG_CONTRACT, is_valid_key, expected_category, is_system_key
)
from pronto_shared.permissions import Permission, ROLE_PERMISSIONS

class DatabaseValidator:
    """Validates and seeds database with strict contract enforcement"""

    def __init__(self):
        self.created_data = []
        self.updated_data = []
        self.deleted_data = []

    def print_header(self, text: str):
        print(f"\n{'=' * 80}")
        print(f"  {text}")
        print(f"{'=' * 80}")

    def validate_integrity(self, db) -> bool:
        """
        Hard-Gate: Verifica que no existan llaves legacy o fuera de contrato.
        Retorna False si debe abortar el proceso.
        """
        print("\n🔍 Auditando llaves de configuración...")
        settings = db.query(SystemSetting).all()
        valid = True

        for s in settings:
            key = s.config_key
            
            # 1. Check for UPPERCASE (Hard Fail)
            if re.search(r"[A-Z]", key):
                log.error(f"❌ LLAVE LEGACY DETECTADA: '{key}' contiene mayúsculas. V6 exige lowercase.")
                valid = False
            
            # 2. Check for Contract Compliance (Hard Fail)
            if not is_valid_key(key):
                log.error(f"❌ LLAVE NO RECONOCIDA: '{key}' no existe en CONFIG_CONTRACT.")
                valid = False
            
            # 3. Check for correct category (Auto-fixable)
            target_cat = expected_category(key)
            if s.category != target_cat:
                log.warning(f"⚠️ Categoría incorrecta para '{key}': '{s.category}' -> '{target_cat}' (Corrigiendo...)")
                s.category = target_cat
                self.updated_data.append(f"Category: {key}")

        return valid

    def migrate_legacy_keys(self, db):
        """Migración determinista de llaves UPPERCASE conocidas a sus canónicas."""
        print("\n🧹 Migrando datos legacy...")
        
        # Mover RESTAURANT_NAME a restaurant_name
        legacy_name = db.query(SystemSetting).filter(SystemSetting.config_key == 'RESTAURANT_NAME').first()
        if legacy_name:
            # Solo copiar si no existe la nueva o si queremos sobrescribir con el valor viejo
            canonical = db.query(SystemSetting).filter(SystemSetting.config_key == 'restaurant_name').first()
            if not canonical:
                log.info(f"Copiando 'RESTAURANT_NAME' -> 'restaurant_name'")
                new_setting = SystemSetting(
                    config_key='restaurant_name',
                    config_value=legacy_name.config_value,
                    value_type='string',
                    category='business'
                )
                db.add(new_setting)
                self.created_data.append("restaurant_name (migrated)")
            
            # Borrar la vieja
            db.delete(legacy_name)
            self.deleted_data.append("RESTAURANT_NAME (deleted)")
            db.flush()

    def seed_business_config(self, db):
        """Idempotent UPSERT for business configuration based on CONTRACT"""
        print("\n🌱 Sincronizando configuración desde el Contrato...")
        
        for key, spec in CONFIG_CONTRACT.items():
            existing = db.query(SystemSetting).filter(SystemSetting.config_key == key).first()
            
            val = str(spec["default"])
            if spec["type"] == "bool":
                val = "true" if spec["default"] else "false"
            
            if not existing:
                log.info(f"Creando setting faltante: {key}")
                setting = SystemSetting(
                    config_key=key,
                    config_value=val,
                    value_type=spec["type"],
                    category=expected_category(key),
                    display_name=key.replace(".", " ").replace("_", " ").title(),
                    description=spec.get("description", "")
                )
                db.add(setting)
                self.created_data.append(f"Config: {key}")
            else:
                # Asegurar integridad de metadatos (tipo y categoría)
                changed = False
                if existing.value_type != spec["type"]:
                    existing.value_type = spec["type"]
                    changed = True
                
                target_cat = expected_category(key)
                if existing.category != target_cat:
                    existing.category = target_cat
                    changed = True
                
                if changed:
                    self.updated_data.append(f"Metadata: {key}")

        db.commit()

    def seed_rbac(self, db):
        """Idempotent UPSERT for RBAC system"""
        print("\n🌱 Sincronizando Roles y Permisos (RBAC)...")

        has_created_at = db.execute(
            text(
                """
                SELECT 1
                FROM information_schema.columns
                WHERE table_name = 'pronto_system_permissions'
                  AND column_name = 'created_at'
                LIMIT 1
                """
            )
        ).first()
        if not has_created_at:
            log.warning(
                "⚠️ Esquema RBAC legacy detectado (sin created_at en pronto_system_permissions). "
                "Se omite seed_rbac en este entorno."
            )
            return
        
        for perm in Permission:
            code = perm.value
            category = code.split(":")[0] if ":" in code else "general"
            existing = db.query(SystemPermission).filter(SystemPermission.code == code).first()
            if not existing:
                db.add(SystemPermission(code=code, category=category, description=f"Permiso para {code}"))
                self.created_data.append(f"Permission: {code}")
        db.flush()

        for role_name, perms in ROLE_PERMISSIONS.items():
            role = db.query(SystemRole).filter(SystemRole.name == role_name).first()
            if not role:
                role = SystemRole(name=role_name, display_name=role_name.capitalize(), is_custom=False)
                db.add(role)
                db.flush()
                self.created_data.append(f"Role: {role_name}")
            
            current_bindings = {b.permission.code for b in role.permissions if b.permission}
            target_codes = {p.value for p in perms}
            
            for code in target_codes:
                if code not in current_bindings:
                    perm = db.query(SystemPermission).filter(SystemPermission.code == code).first()
                    if perm:
                        db.add(RolePermissionBinding(role_id=role.id, permission_id=perm.id))
                        self.updated_data.append(f"Binding: {role_name} -> {code}")
        
        db.commit()

    def seed_menu_catalog(self, db):
        """Ensures customer menu keeps minimum viable coverage for QA flows."""
        print("\n🌱 Sincronizando catálogo de menú (mínimo QA)...")
        required_groups = {
            "appetizers": {"appetizers", "entradas", "appetizer", "starters"},
            "beverages": {"beverages", "bebidas", "drinks", "beverage"},
            "combos": {"combos", "combo"},
            "main_courses": {"main courses", "main_course", "platos fuertes", "platos_fuertes"},
            "desserts": {"desserts", "postres", "dessert", "postre"},
        }
        defaults = {
            "appetizers": ("Entrada de prueba", "Entrada de soporte para QA", Decimal("9.99")),
            "beverages": ("Bebida de prueba", "Bebida de soporte para QA", Decimal("3.99")),
            "combos": ("Combo de prueba", "Combo de soporte para QA", Decimal("14.99")),
            "main_courses": ("Plato fuerte de prueba", "Plato principal de soporte para QA", Decimal("18.99")),
            "desserts": ("Postre de prueba", "Postre de soporte para QA", Decimal("6.99")),
        }

        for group_name, aliases in required_groups.items():
            category_rows = (
                db.execute(
                    select(MenuCategory.id)
                    .where(func.lower(func.trim(MenuCategory.name)).in_(list(aliases)))
                    .order_by(MenuCategory.display_order.asc(), MenuCategory.name.asc())
                )
                .all()
            )
            if not category_rows:
                continue

            category_ids = [row[0] for row in category_rows]
            available_count = (
                db.query(MenuItem)
                .filter(MenuItem.category_id.in_(category_ids), MenuItem.is_available.is_(True))
                .count()
            )

            if available_count >= 3:
                continue

            missing = 3 - int(available_count)
            unavailable_items = (
                db.query(MenuItem)
                .filter(MenuItem.category_id.in_(category_ids), MenuItem.is_available.is_(False))
                .order_by(MenuItem.name.asc())
                .limit(missing)
                .all()
            )
            for item in unavailable_items:
                item.is_available = True
            updated = len(unavailable_items)
            missing -= int(updated)

            if missing > 0:
                target_category_id = category_ids[0]
                base_name, base_desc, base_price = defaults[group_name]
                for idx in range(1, missing + 1):
                    db.add(
                        MenuItem(
                            id=uuid4(),
                            category_id=target_category_id,
                            name=f"{base_name} {idx}",
                            description=base_desc,
                            price=base_price,
                            image_path="/assets/pronto/menu/placeholder-food.webp",
                            is_available=True,
                            preparation_time_minutes=10,
                            is_quick_serve=False,
                        )
                    )

        db.commit()
        self.updated_data.append("Menu catalog seeded (UPSERT)")

    def validate_menu_coverage(self, db, min_items_per_type: int = 3) -> bool:
        """
        Validates that main customer categories have enough available items for QA flows.
        """
        print(f"\n🔍 Validando cobertura de menú (mínimo {min_items_per_type} por tipo)...")
        required_groups = {
            "appetizers": {"appetizers", "entradas", "appetizer", "starters"},
            "beverages": {"beverages", "bebidas", "drinks", "beverage"},
            "combos": {"combos", "combo"},
            "main_courses": {"main courses", "main_course", "platos fuertes", "platos_fuertes"},
            "desserts": {"desserts", "postres", "dessert", "postre"},
        }

        rows = db.execute(
            text(
                """
                SELECT LOWER(TRIM(c.name)) AS category_name,
                       COUNT(mi.id) FILTER (WHERE mi.is_available) AS available_count
                FROM pronto_menu_categories c
                LEFT JOIN pronto_menu_items mi ON mi.category_id = c.id
                GROUP BY LOWER(TRIM(c.name))
                """
            )
        ).fetchall()
        counts = {str(name or "").strip().lower(): int(available or 0) for name, available in rows}

        valid = True
        for group_name, aliases in required_groups.items():
            group_total = sum(counts.get(alias, 0) for alias in aliases)
            if group_total < min_items_per_type:
                log.error(
                    "❌ Cobertura insuficiente en '%s': %s disponibles (mínimo %s)",
                    group_name,
                    group_total,
                    min_items_per_type,
                )
                valid = False
            else:
                log.info("✓ %s: %s disponibles", group_name, group_total)

        return valid

    def run_validation(self):
        self.print_header("VALIDACIÓN Y SEED DE BASE DE DATOS (V6 ZERO LEGACY)")
        try:
            from pronto_shared.config import load_config
            from pronto_shared.db import init_engine
            config = load_config("validate_seed")
            init_engine(config)

            with get_session() as db:
                # 1. Migrar lo conocido antes de validar
                self.migrate_legacy_keys(db)
                
                # 2. Hard-Gate de integridad
                if not self.validate_integrity(db):
                    self.print_header("❌ FALLO DE INTEGRIDAD CRÍTICO")
                    log.error("El proceso se detuvo porque se detectaron llaves legacy o inválidas.")
                    log.error("Limpia la base de datos o corrige las llaves manualmente antes de continuar.")
                    return 1

                # 3. Procesar Seeds
                self.print_header("2. PROCESANDO CAMBIOS")
                self.seed_business_config(db)
                self.seed_menu_catalog(db)
                self.seed_rbac(db)
                if not self.validate_menu_coverage(db):
                    self.print_header("❌ FALLO DE COBERTURA DE MENÚ")
                    log.error("El seed no cumple el mínimo de productos por categoría requerida.")
                    return 1

                self.print_header("RESUMEN")
                print(f"✅ Creados: {len(self.created_data)}")
                print(f"🔄 Actualizados: {len(self.updated_data)}")
                print(f"🗑️ Eliminados: {len(self.deleted_data)}")
                return 0
        except Exception as e:
            print(f"\n❌ ERROR CRÍTICO: {e}")
            import traceback
            traceback.print_exc()
            return 1

if __name__ == "__main__":
    sys.exit(DatabaseValidator().run_validation())
