#!/usr/bin/env python3
"""Script simple de seed para la base de datos PRONTO"""

import psycopg2
from psycopg2 import sql
import sys

DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 5432,
    "dbname": "pronto",
    "user": "pronto",
    "password": "pronto123",
}

SEED_SQL = """
-- Áreas
INSERT INTO pronto_areas (name, description, prefix, color, created_at, updated_at, is_active)
VALUES 
    ('Terraza', 'Terraza exterior', 'TZ', '#ff6b35', NOW(), NOW(), true),
    ('Comedor Principal', 'Área principal', 'CM', '#4ecdc4', NOW(), NOW(), true),
    ('Barra', 'Área de barra', 'BR', '#45b7d1', NOW(), NOW(), true),
    ('Salón VIP', 'Salón privado', 'VP', '#9c27b0', NOW(), NOW(), true),
    ('Jardín', 'Jardín exterior', 'JD', '#ffeead', NOW(), NOW(), true)
ON CONFLICT (name) DO NOTHING;

-- Categorías del menú
INSERT INTO pronto_menu_categories (name, description, display_order)
VALUES 
    ('Bebidas', 'Refrescos, jugos y café', 1),
    ('Entradas', 'Para comenzar tu comida', 2),
    ('Hamburguesas', 'Clásicas y especiales', 3),
    ('Pizzas', 'Pizza artesanal', 4),
    ('Platos Fuertes', 'Comida principal', 5),
    ('Postres', 'Dulces y pasteles', 6)
ON CONFLICT DO NOTHING;

-- Configuración del negocio
INSERT INTO pronto_business_config (config_key, config_value, value_type, category, display_name, description)
VALUES 
    ('restaurant_name', '"Cafetería de Prueba"', 'string', 'general', 'Nombre del restaurante', 'Nombre del restaurante'),
    ('tax_rate', '0.16', 'number', 'general', 'Porcentaje de impuestos', 'Porcentaje de impuestos'),
    ('currency', '"MXN"', 'string', 'general', 'Moneda', 'Moneda'),
    ('timezone', '"America/Mexico_City"', 'string', 'general', 'Zona horaria', 'Zona horaria')
ON CONFLICT (config_key) DO NOTHING;

-- Períodos del día
INSERT INTO pronto_day_periods (period_key, name, display_order, start_time, end_time, is_default)
VALUES 
    ('breakfast', 'Desayuno', 1, '07:00', '11:00', false),
    ('lunch', 'Comida', 2, '13:00', '17:00', false),
    ('dinner', 'Cena', 3, '19:00', '23:00', false),
    ('all_day', 'Todo el día', 4, '00:00', '23:59', true)
ON CONFLICT (period_key) DO NOTHING;

-- Etiquetas de estados de orden
INSERT INTO pronto_order_status_labels (status_key, client_label, employee_label, admin_desc, version)
VALUES 
    ('pending', 'Pendiente', 'Pendiente', 'Orden pendiente de confirmación', 1),
    ('confirmed', 'Confirmado', 'Confirmado', 'Orden confirmada por el cliente', 1),
    ('preparing', 'Preparando', 'En preparación', 'Orden siendo preparada en cocina', 1),
    ('ready', 'Listo', 'Listo para entregar', 'Orden lista para entrega', 1),
    ('delivered', 'Entregado', 'Entregado', 'Orden entregada al cliente', 1),
    ('cancelled', 'Cancelado', 'Cancelado', 'Orden cancelada', 1),
    ('paid', 'Pagado', 'Pagado', 'Orden pagada', 1)
ON CONFLICT (status_key) DO NOTHING;

-- System roles
INSERT INTO pronto_system_roles (name, display_name, description, is_custom)
VALUES 
    ('admin', 'Administrador', 'Acceso total al sistema', false),
    ('manager', 'Gerente', 'Gestión del restaurante', false),
    ('waiter', 'Mesero', 'Atención a mesas', false),
    ('chef', 'Cocinero', 'Preparación de órdenes', false),
    ('cashier', 'Cajero', 'Procesamiento de pagos', false),
    ('host', 'Anfitrión', 'Gestión de clientes', false)
ON CONFLICT (name) DO NOTHING;

-- System permissions
INSERT INTO pronto_system_permissions (code, category, description)
VALUES 
    ('orders_create', 'orders', 'Crear nuevas órdenes'),
    ('orders_read', 'orders', 'Ver órdenes existentes'),
    ('orders_update', 'orders', 'Modificar órdenes'),
    ('orders_delete', 'orders', 'Cancelar órdenes'),
    ('tables_manage', 'tables', 'Administrar mesas'),
    ('menu_manage', 'menu', 'Administrar productos'),
    ('reports_view', 'reports', 'Acceso a reportes'),
    ('settings_manage', 'settings', 'Configuración del sistema')
ON CONFLICT (code) DO NOTHING;

-- Atajos de teclado
INSERT INTO pronto_keyboard_shortcuts (combo, description, category, callback_function, is_enabled, prevent_default, sort_order)
VALUES 
    ('ctrl+n', 'Nueva orden', 'orders', 'newOrder', true, true, 1),
    ('ctrl+s', 'Buscar mesa', 'tables', 'searchTable', true, true, 2),
    ('f1', 'Ayuda', 'global', 'help', true, true, 3),
    ('esc', 'Cancelar', 'global', 'cancel', true, true, 4),
    ('enter', 'Confirmar', 'global', 'confirm', true, true, 5)
ON CONFLICT DO NOTHING;
"""


def main():
    print("Conectando a la base de datos...")
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = True
        cur = conn.cursor()

        print("Ejecutando seed...")
        cur.execute(SEED_SQL)

        print("Verificando datos insertados...")
        cur.execute("SELECT COUNT(*) FROM pronto_areas")
        areas_count = cur.fetchone()[0]
        print(f"  Áreas: {areas_count}")

        cur.execute("SELECT COUNT(*) FROM pronto_menu_categories")
        categories_count = cur.fetchone()[0]
        print(f"  Categorías: {categories_count}")

        cur.execute("SELECT COUNT(*) FROM pronto_business_config")
        configs_count = cur.fetchone()[0]
        print(f"  Configuraciones: {configs_count}")

        cur.execute("SELECT COUNT(*) FROM pronto_order_status_labels")
        statuses_count = cur.fetchone()[0]
        print(f"  Estados de orden: {statuses_count}")

        cur.execute("SELECT COUNT(*) FROM pronto_system_roles")
        roles_count = cur.fetchone()[0]
        print(f"  Roles del sistema: {roles_count}")

        cur.execute("SELECT COUNT(*) FROM pronto_system_permissions")
        permissions_count = cur.fetchone()[0]
        print(f"  Permisos del sistema: {permissions_count}")

        cur.close()
        conn.close()

        print("\n✓ Seed completado exitosamente!")

    except Exception as e:
        print(f"\n✗ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
