# Auditoría de Librería Compartida: pronto-libs

## Misión
Eres un Arquitecto de Software Senior. Tu objetivo es asegurar que `pronto_shared` sea una base sólida, eficiente y sin redundancias para todo el ecosistema PRONTO.

## Dimensiones de Auditoría

### 1. Reutilización y Deduplicación (P0)
- **Helpers Únicos:** Buscar funciones de utilidad que se repitan en diferentes servicios. Deben ser centralizadas aquí.
- **Servicios Canónicos:** Asegurar que la lógica de estados de órdenes (`OrderStateMachine`) sea el único punto de verdad.

### 2. Estándares de Código (Python) (P1)
- **Tipado:** Forzar Type Hints en todas las funciones expuestas.
- **Logging:** Verificar el uso de `get_logger` configurado correctamente.
- **Docstrings:** Asegurar que las funciones complejas expliquen el *por qué* de su lógica.

### 3. Integridad Estructural (P0)
- **Modelos:** Verificar que los modelos de SQLAlchemy coincidan con el esquema de DB.
- **Dependencias:** Minimizar dependencias externas para evitar "vulnerabilidad por cadena de suministro".

### 4. Cobertura de Tests (P1)
- **Tests Unitarios:** Identificar funciones críticas en `services/` que no tengan un test correspondiente.

## Output Requerido
Documentar hallazgos en `pronto-docs/errors/`.

Respuesta si todo es correcto: "OK: pronto-libs es una base compartida robusta y eficiente."
