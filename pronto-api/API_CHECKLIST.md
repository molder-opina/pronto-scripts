# Pronto API Checklist

**Base URL:** `http://localhost:6082`
**Fecha de creación:** 2026-02-01

## Tabla de Contenidos
1. [Health Endpoints](#health-endpoints)
2. [Client APIs](#client-apis)
3. [Employee APIs](#employee-apis)

---

## Health Endpoints

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 1 | Health Check | GET | `/health` | Verificar estado general del servicio | ☐ |
| 2 | Client Health | GET | `/api/client/health` | Verificar estado del módulo cliente | ☐ |
| 3 | Employee Health | GET | `/api/employee/health` | Verificar estado del módulo empleado | ☐ |

---

## Client APIs

### Autenticación (`/api/client/auth`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 4 | Register | POST | `/api/client/auth/register` | Registrar nuevo cliente | ☐ |
| 5 | Login | POST | `/api/client/auth/login` | Iniciar sesión de cliente | ☐ |
| 6 | Password Recovery | POST | `/api/client/auth/password/recover` | Recuperar contraseña | ☐ |
| 7 | Password Reset | POST | `/api/client/auth/password/reset` | Restablecer contraseña | ☐ |

### Menú (`/api/client/menu`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 8 | Get Menu | GET | `/api/client/menu` | Obtener menú completo | ☐ |
| 9 | Get Categories | GET | `/api/client/menu/categories` | Obtener categorías del menú | ☐ |

### Órdenes (`/api/client/orders`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 10 | Get Orders | GET | `/api/client/orders` | Obtener órdenes del cliente | ☐ |
| 11 | Create Order | POST | `/api/client/orders` | Crear nueva orden | ☐ |
| 12 | Get Order Status | GET | `/api/client/orders/{id}` | Obtener estado de orden específica | ☐ |

### Pagos (`/api/client/payments`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 13 | Get Payment Methods | GET | `/api/client/payments/methods` | Obtener métodos de pago disponibles | ☐ |
| 14 | Process Payment | POST | `/api/client/payments/process` | Procesar pago | ☐ |

### Sesiones (`/api/client/sessions`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 15 | Get Active Sessions | GET | `/api/client/sessions` | Obtener sesiones activas | ☐ |
| 16 | Join Session | POST | `/api/client/sessions/join` | Unirse a una sesión | ☐ |
| 17 | Leave Session | POST | `/api/client/sessions/leave` | Salir de una sesión | ☐ |

### Promociones (`/api/client/promotions`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 18 | Get Promotions | GET | `/api/client/promotions` | Obtener promociones disponibles | ☐ |
| 19 | Validate Promo Code | POST | `/api/client/promotions/validate` | Validar código promocional | ☐ |

### Llamadas de Mesero (`/api/notifications/waiter`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 20 | Call Waiter | POST | `/api/call-waiter` | Llamar al mesero | ☐ |
| 21 | Waiter Call Status | GET | `/api/notifications/waiter/status/{id}` | Consultar estado de llamada | ☐ |

### Notificaciones (`/api/client/notifications`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 23 | Get Notifications | GET | `/api/client/notifications` | Obtener notificaciones | ☐ |
| 24 | Mark Notification Read | PATCH | `/api/client/notifications/{id}/read` | Marcar notificación como leída | ☐ |

### Otros (`/api/client`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 25 | Get Avatars | GET | `/api/client/avatars` | Obtener avatares disponibles | ☐ |
| 26 | Get Business Info | GET | `/api/client/business-info` | Obtener información del negocio | ☐ |
| 27 | Get Config | GET | `/api/client/config` | Obtener configuración del cliente | ☐ |
| 28 | Get Shortcuts | GET | `/api/client/shortcuts` | Obtener atajos | ☐ |
| 29 | Submit Feedback | POST | `/api/client/feedback` | Enviar retroalimentación | ☐ |
| 30 | Get Support Info | GET | `/api/client/support` | Obtener información de soporte | ☐ |
| 31 | Get Split Bills Options | GET | `/api/client/split-bills` | Obtener opciones de разделить счет | ☐ |

---

## Employee APIs

### Autenticación (`/api/employee/auth`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 32 | Login | POST | `/api/employee/auth/login` | Iniciar sesión de empleado | ☐ |
| 33 | Verify Token | GET | `/api/employee/auth/verify` | Verificar token | ☐ |
| 34 | Get Me | GET | `/api/employee/auth/me` | Obtener información del empleado actual | ☐ |
| 35 | Get Permissions | GET | `/api/employee/auth/permissions` | Obtener permisos del empleado | ☐ |
| 36 | Logout | POST | `/api/employee/auth/logout` | Cerrar sesión | ☐ |

### Gestión de Empleados (`/api/employee/employees`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 37 | Get Employees | GET | `/api/employee/employees` | Obtener lista de empleados | ☐ |
| 38 | Get Employee by ID | GET | `/api/employee/employees/{id}` | Obtener empleado específico | ☐ |
| 39 | Create Employee | POST | `/api/employee/employees` | Crear nuevo empleado | ☐ |
| 40 | Update Employee | PATCH | `/api/employee/employees/{id}` | Actualizar empleado | ☐ |

### Menú (`/api/employee/menu`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 41 | Get Menu Items | GET | `/api/employee/menu/items` | Obtener items del menú | ☐ |
| 42 | Get Menu Categories | GET | `/api/employee/menu/categories` | Obtener categorías del menú | ☐ |
| 43 | Create Menu Item | POST | `/api/employee/menu/items` | Crear item del menú | ☐ |
| 44 | Update Menu Item | PATCH | `/api/employee/menu/items/{id}` | Actualizar item del menú | ☐ |

### Órdenes (`/api/employee/orders`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 45 | Get Orders | GET | `/api/employee/orders` | Obtener todas las órdenes | ☐ |
| 46 | Get Order by ID | GET | `/api/employee/orders/{id}` | Obtener orden específica | ☐ |
| 47 | Update Order Status | PATCH | `/api/employee/orders/{id}/status` | Actualizar estado de orden | ☐ |
| 48 | Get Order Items | GET | `/api/employee/orders/{id}/items` | Obtener items de una orden | ☐ |

### Mesas (`/api/employee/tables`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 49 | Get Tables | GET | `/api/employee/tables` | Obtener lista de mesas | ☐ |
| 50 | Get Table by ID | GET | `/api/employee/tables/{id}` | Obtener mesa específica | ☐ |
| 51 | Create Table | POST | `/api/employee/tables` | Crear nueva mesa | ☐ |
| 52 | Update Table | PATCH | `/api/employee/tables/{id}` | Actualizar mesa | ☐ |

### Sesiones (`/api/employee/sessions`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 53 | Get Sessions | GET | `/api/employee/sessions` | Obtener sesiones | ☐ |
| 54 | Get Session by ID | GET | `/api/employee/sessions/{id}` | Obtener sesión específica | ☐ |
| 55 | Create Session | POST | `/api/employee/sessions` | Crear nueva sesión | ☐ |
| 56 | Close Session | PATCH | `/api/employee/sessions/{id}/close` | Cerrar sesión | ☐ |

### Clientes (`/api/employee/customers`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 57 | Get Customers | GET | `/api/employee/customers` | Obtener lista de clientes | ☐ |
| 58 | Get Customer by ID | GET | `/api/employee/customers/{id}` | Obtener cliente específico | ☐ |

### Llamadas de Mesero (`/api/notifications/waiter`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 59 | Get Waiter Calls | GET | `/api/notifications/waiter/pending` | Obtener llamadas al mesero | ☐ |
| 60 | Confirm Waiter Call | POST | `/api/notifications/waiter/confirm/{id}` | Confirmar llamada al mesero | ☐ |

### Promociones (`/api/employee/promotions`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 61 | Get Promotions | GET | `/api/employee/promotions` | Obtener promociones | ☐ |
| 62 | Create Promotion | POST | `/api/employee/promotions` | Crear promoción | ☐ |
| 63 | Update Promotion | PATCH | `/api/employee/promotions/{id}` | Actualizar promoción | ☐ |

### Códigos de Descuento (`/api/employee/discount-codes`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 64 | Get Discount Codes | GET | `/api/employee/discount-codes` | Obtener códigos de descuento | ☐ |
| 65 | Validate Discount Code | POST | `/api/employee/discount-codes/validate` | Validar código de descuento | ☐ |

### Reportes (`/api/employee/reports`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 66 | Get Sales Report | GET | `/api/employee/reports/sales` | Obtener reporte de ventas | ☐ |
| 67 | Get Daily Summary | GET | `/api/employee/reports/daily` | Obtener resumen diario | ☐ |
| 68 | Get Popular Items | GET | `/api/employee/reports/popular-items` | Obtener items populares | ☐ |

### Analíticas (`/api/employee/analytics`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 69 | Get Dashboard Stats | GET | `/api/employee/analytics/dashboard` | Obtener estadísticas del dashboard | ☐ |
| 70 | Get Revenue Stats | GET | `/api/employee/analytics/revenue` | Obtener estadísticas de ingresos | ☐ |
| 71 | Get Order Stats | GET | `/api/employee/analytics/orders` | Obtener estadísticas de órdenes | ☐ |

### Configuración (`/api/employee/settings`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 72 | Get Settings | GET | `/api/employee/settings` | Obtener configuración | ☐ |
| 73 | Update Settings | PATCH | `/api/employee/settings` | Actualizar configuración | ☐ |

### Información del Negocio (`/api/employee/business-info`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 74 | Get Business Info | GET | `/api/employee/business-info` | Obtener información del negocio | ☐ |
| 75 | Update Business Info | PATCH | `/api/employee/business-info` | Actualizar información del negocio | ☐ |

### Personalización (`/api/employee/branding`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 76 | Get Branding | GET | `/api/employee/branding` | Obtener personalización | ☐ |
| 77 | Update Branding | PATCH | `/api/employee/branding` | Actualizar personalización | ☐ |

### Áreas (`/api/employee/areas`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 78 | Get Areas | GET | `/api/employee/areas` | Obtener áreas | ☐ |
| 79 | Create Area | POST | `/api/employee/areas` | Crear área | ☐ |

### Roles (`/api/employee/roles`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 80 | Get Roles | GET | `/api/employee/roles` | Obtener roles | ☐ |
| 81 | Get Role by ID | GET | `/api/employee/roles/{id}` | Obtener rol específico | ☐ |

### Notificaciones (`/api/employee/notifications`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 82 | Get Notifications | GET | `/api/employee/notifications` | Obtener notificaciones | ☐ |
| 83 | Send Notification | POST | `/api/employee/notifications` | Enviar notificación | ☐ |

### Asignación de Mesas (`/api/employee/table-assignments`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 84 | Get Table Assignments | GET | `/api/employee/table-assignments` | Obtener asignaciones de mesas | ☐ |
| 85 | Assign Table | POST | `/api/employee/table-assignments` | Asignar mesa | ☐ |

### Períodos del Día (`/api/employee/day-periods`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 86 | Get Day Periods | GET | `/api/employee/day-periods` | Obtener períodos del día | ☐ |

### Retroalimentación (`/api/employee/feedback`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 87 | Get Feedback | GET | `/api/employee/feedback` | Obtener retroalimentación | ☐ |
| 88 | Get Feedback by ID | GET | `/api/employee/feedback/{id}` | Obtener retroalimentación específica | ☐ |

### Imágenes (`/api/employee/images`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 89 | Get Images | GET | `/api/employee/images` | Obtener imágenes | ☐ |
| 90 | Upload Image | POST | `/api/employee/images` | Subir imagen | ☐ |

### Modificadores (`/api/employee/modifiers`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 91 | Get Modifiers | GET | `/api/employee/modifiers` | Obtener modificadores | ☐ |
| 92 | Create Modifier | POST | `/api/employee/modifiers` | Crear modificador | ☐ |

### Tiempo Real (`/api/employee/realtime`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 93 | Get Realtime Status | GET | `/api/employee/realtime/status` | Obtener estado en tiempo real | ☐ |

### Configuración Admin (`/api/employee/admin`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 94 | Get Admin Config | GET | `/api/employee/admin/config` | Obtener configuración de admin | ☐ |
| 95 | Update Admin Config | PATCH | `/api/employee/admin/config` | Actualizar configuración de admin | ☐ |

### Debug (`/api/employee/debug`)

| # | Endpoint | Método | Ruta | Descripción | Validado |
|---|----------|--------|------|-------------|----------|
| 96 | Get Debug Info | GET | `/api/employee/debug/info` | Obtener información de debug | ☐ |

---

## Resumen

| Categoría | Total de Endpoints |
|-----------|-------------------|
| Health Endpoints | 3 |
| Client APIs | 31 |
| Employee APIs | 62 |
| **Total** | **96** |

---

## Comandos para Validación

### Validación Simple (sin dependencias async)
```bash
python test_api_simple.py
```

### Validación Completa (con Rich y aiohttp)
```bash
python test_api_validation.py
```

### Configuración de Variables de Entorno
Crear archivo `.env` con:
```
API_BASE_URL=http://localhost:6082
ADMIN_EMAIL=admin@pronto.com
ADMIN_PASSWORD=admin123
```
