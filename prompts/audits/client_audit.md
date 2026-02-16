# Auditoría de Flujo Comensal y Seguridad: pronto-client

## Misión
Garantizar que el flujo de orden del cliente es infalible, los datos están protegidos y la aplicación no contiene lógica de presentación pesada o activos locales.

## Dimensiones Críticas de Auditoría

### 1. Integridad del Flujo de Orden (P0)
- **Carrito y Checkout:** Validar que el proceso desde elegir modificadores hasta el pago sea lógico. Detectar si es posible crear órdenes con montos `0.0` o sin items.
- **Email de Confirmación:** Verificar que el paso de captura de email sea obligatorio y esté bien validado.
- **Sincronización:** Asegurar que el cliente no pueda modificar una orden una vez que el Chef la ha iniciado (`preparing`).

### 2. Purga de Contenido Estático (P0)
- **No Assets Locales:** Eliminar cualquier archivo estático de `pronto-client`. Todo debe ser servido por el puerto `9088` (`pronto-static`).
- **Inyección de Assets:** Verificar que se usen las variables `assets_css_clients` y `assets_js_clients`.

### 3. Seguridad y Privacidad (P0)
- **Session Leak:** Detectar si se están guardando datos como Email, Nombre o Teléfono en `flask.session`. **USAR SOLO LLAVES PERMITIDAS** en `customer_session.py`.
- **Imports:** Verificar que no existan dependencias circulares o imports directos desde folders de `pronto-employees` o `pronto-api` (usar siempre `pronto_shared`).

### 4. Usabilidad y Deuda Técnica
- **UX Crítica:** Detectar botones difíciles de presionar o flujos que requieren demasiados clics.
- **Legacy:** Quitar cualquier referencia a "Mesas" o "Áreas" con formatos antiguos no compatibles con el nuevo `area_id`.

## Output Requerido
Si encuentras datos personales en sesión o estáticos locales, documentar como ALTA. Si el checkout se rompe, documentar como BLOQUEANTE.

Respuesta si todo es correcto: "OK: pronto-client mantiene flujo seguro y estáticos externos."
