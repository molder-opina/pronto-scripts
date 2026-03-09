# Auditoría de Flujo Operativo y Estáticos: pronto-employees

## Misión
Asegurar que la consola de empleados es una interfaz pura de visualización y ejecución de lógica de negocio, sin activos locales y con flujos operativos blindados.

## Dimensiones Críticas de Auditoría

### 1. Blindaje de Flujo Operativo (P0)
- **Transiciones UI:** Verificar que las acciones de la interfaz (botones "Iniciar", "Entregar", "Cobrar") llamen estrictamente a los endpoints que disparan la `OrderStateMachine`.
- **Visibilidad de Datos:** ¿El Chef ve exactamente lo que necesita (modificadores, notas)? ¿El Waiter ve los estados de cocina en tiempo real?
- **Fallos Lógicos:** Detectar si la UI permite estados imposibles (ej: botón de cobro activo en orden no entregada).

### 2. Purga de Contenido Estático (P0)
- **Aislamiento Total:** Prohibido tener archivos `.css`, `.js`, fuentes o imágenes dentro de `pronto-employees/src`. **Tercera advertencia: Todo debe vivir en pronto-static.**
- **Variables de Contexto:** Verificar el uso de `assets_css_employees` y `assets_js_employees`. Cualquier URL relativa a `/static/` local es un error.

### 3. Deduplicación y Estándares (P1)
- **Templates:** Detectar lógica duplicada en `orders_waiter.html`, `orders_chef.html`, etc. Mover lógica común a macros de Jinja o componentes Vue compartidos.
- **Legacy:** Identificar rutas o vistas de versiones anteriores (ej: roles no canónicos como `admin_roles`).

### 4. Seguridad de Sesión (P0)
- **Cookie Path:** Verificar que las sesiones no se crucen entre scopes.
- **Auth Wrapper:** Asegurar que todas las mutaciones pasen por el wrapper centralizado con token CSRF.

## Output Requerido
Documentar cada bug encontrado en `pronto-docs/errors/`. Si detectas estáticos locales, la severidad es ALTA. Si detectas ruptura de flujo de negocio, la severidad es BLOQUEANTE.

Respuesta si todo es correcto: "OK: pronto-employees cumple con aislamiento de estáticos y flujo operativo."
