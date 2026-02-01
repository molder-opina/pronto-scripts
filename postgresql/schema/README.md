# Esquema de Base de Datos - PRONTO

## Script Principal

### `create_schema_pronto_v2.sql`
Script completo que crea todas las tablas basadas en los modelos ORM actuales de `models.py`.

```bash
psql -U postgres -d pronto -f schema/create_schema_pronto_v2.sql
```

## Resumen de Tablas (50+)

### Core
- `pronto_customers` - Clientes con campos encriptados
- `pronto_employees` - Empleados
- `pronto_employee_preferences` - Preferencias de empleados

### Restaurante
- `pronto_areas` - Áreas (Terraza, Interior, VIP, etc.)
- `pronto_tables` - Mesas con QR codes

### Menú
- `pronto_menu_categories` - Categorías
- `pronto_menu_items` - Productos
- `pronto_modifier_groups` - Grupos de modificadores
- `pronto_modifiers` - Aditamentos/modificadores
- `pronto_menu_item_modifier_groups` - Relación productos-modificadores
- `pronto_day_periods` - Períodos del día
- `pronto_menu_item_day_periods` - Items-períodos
- `pronto_product_schedules` - Horarios de productos

### Órdenes
- `pronto_dining_sessions` - Sesiones de comedor
- `pronto_orders` - Órdenes
- `pronto_order_items` - Items de orden
- `pronto_order_item_modifiers` - Modificadores de items
- `pronto_order_status_history` - Historial de estados
- `pronto_order_status_labels` - Etiquetas de estados
- `pronto_order_modifications` - Modificaciones de órdenes

### Empleados
- `pronto_route_permissions` - Permisos de rutas
- `pronto_employee_route_access` - Acceso a rutas
- `pronto_waiter_table_assignments` - Asignación meseros-mesas
- `pronto_table_transfer_requests` - Transferencias de mesa
- `pronto_waiter_calls` - Llamadas de mesero

### Configuración
- `pronto_business_config` - Configuraciones
- `pronto_business_info` - Info del negocio (singleton)
- `pronto_business_schedule` - Horario del negocio
- `pronto_system_settings` - Configuraciones del sistema
- `pronto_secrets` - Secretos

### Seguridad
- `pronto_custom_roles` - Roles personalizados
- `pronto_role_permissions` - Permisos de roles
- `pronto_system_roles` - Roles del sistema
- `pronto_system_permissions` - Permisos del sistema
- `pronto_role_permission_bindings` - Vinculaciones rol-permiso
- `super_admin_handoff_tokens` - Tokens de handoff
- `audit_logs` - Log de auditoría

### Pagos
- `pronto_promotions` - Promociones
- `pronto_discount_codes` - Códigos de descuento
- `pronto_split_bills` - División de cuentas
- `pronto_split_bill_people` - Personas en split
- `pronto_split_bill_assignments` - Asignaciones de items

### Feedback
- `pronto_feedback` - Feedback de clientes
- `pronto_feedback_questions` - Preguntas de feedback
- `pronto_feedback_tokens` - Tokens de feedback

### Utilidades
- `pronto_notifications` - Notificaciones
- `pronto_realtime_events` - Eventos en tiempo real
- `pronto_recommendation_change_log` - Log de recomendaciones
- `pronto_keyboard_shortcuts` - Atajos de teclado
- `pronto_support_tickets` - Tickets de soporte

## Notas

- Todos los campos sensibles están encriptados a nivel aplicación
- Los campos JSONB usan el tipo nativo de PostgreSQL
- Timestamps usan `TIMESTAMP WITHOUT TIME ZONE` por compatibilidad
- Todos los nombres de tablas tienen el prefijo `pronto_`
- Existen algunas tablas fuera del prefijo: `super_admin_handoff_tokens`, `audit_logs`
