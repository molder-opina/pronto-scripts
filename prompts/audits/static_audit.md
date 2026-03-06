# Auditoría de Calidad Estática y Arquitectura: pronto-static

## Misión
Asegurar que `pronto-static` es el cerebro visual del proyecto, con código altamente reutilizable y sin fugas de lógica de negocio hacia el cliente.

## Dimensiones Críticas de Auditoría

### 1. Deduplicación Máxima (P1)
- **Componentes Shared:** Identificar botones, inputs o modales en `employees/` o `clients/` que deberían ser movidos a `vue/shared/`.
- **CSS Common:** Forzar el uso de `assets/css/shared/` para utilerías y componentes base. Detectar colores hardcodeados que no usen variables de `base.css`.

### 2. Calidad de Tipado e Interfaces (P1)
- **Imports Rotas:** Verificar que los alias de TypeScript (`@shared`, `@employees`) funcionen correctamente.
- **Detección de Legacy:** Eliminar cualquier archivo `.js` o `.css` que no esté referenciado en el `manifest.json` actual o que pertenezca a arquitecturas antiguas.

### 3. Integridad de Interfaces (UX)
- **Categorización:** Asegurar que los assets de branding estén en `pronto/branding` y los de productos en `pronto/products`. 
- **Optimización:** Detectar imágenes pesadas o JS innecesario que afecte la usabilidad.

### 4. Blindaje de Wrapper API (P0)
- **Centralización:** Asegurar que NINGÚN componente haga `fetch()` o `axios` directamente. Todo DEBE pasar por el wrapper de `core/http.ts`.
- **Inyección de Cabeceras:** Verificar que `X-CSRFToken` y `X-PRONTO-CUSTOMER-REF` se inyecten según el contexto del host.

## Output Requerido
Documentar fallos de arquitectura (duplicación masiva o fetch directo) como SEVERIDAD: ALTA.

Respuesta si todo es correcto: "OK: pronto-static es el único hub de estáticos y está optimizado."
