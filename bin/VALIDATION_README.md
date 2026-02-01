# Scripts de Validación

Esta carpeta contiene scripts para automatizar la validación de cambios recientes en el proyecto Pronto.

## Scripts Disponibles

### `validate-recent-changes.sh`

Script principal que realiza una validación completa de los cambios recientes usando OpenCode AI.

**Uso:**

```bash
# Revisar últimas 8 horas (por defecto)
bash bin/validate-recent-changes.sh

# Revisar últimas 24 horas
bash bin/validate-recent-changes.sh 24

# Especificar modelo diferente
bash bin/validate-recent-changes.sh 8 opencode/glm-4.7-free
```

**Qué hace:**

1. Revisa el log de commits de las últimas N horas
2. Analiza estadísticas de cambios (git diff --stat)
3. Verifica el estado actual de git
4. Ejecuta la suite completa de pruebas (`bin/test-all.sh`)
5. Analiza los resultados con OpenCode AI usando GLM-4.7 Free
6. Genera un reporte en `tmp/validation-reports/validation_YYYYMMDD_HHMMSS.md`

**Resultados:**

- ✅ Salida 0: Validación exitosa, código seguro
- ❌ Salida 1: Se detectaron problemas, revisar el reporte

### `collect-validation-info.sh`

Script auxiliar que solo recopila la información de validación sin ejecutar el análisis AI.

**Uso:**

```bash
# Recopilar info y enviar a OpenCode manualmente
bash bin/collect-validation-info.sh 8 | opencode run --model opencode/glm-4.7-free

# Guardar en archivo
bash bin/collect-validation-info.sh 8 > validation-info.md
```

**Qué hace:**

1. Log de commits recientes
2. Estadísticas de cambios
3. Estado de git
4. Verificación de servicios
5. Ejecución de pruebas
6. Listado de archivos modificados/eliminados/añadidos

### `validate-seed.sh`

Valida que la base de datos tenga todos los datos necesarios (seed data).

**Uso:**

```bash
bash bin/validate-seed.sh
```

**Qué hace:**

1. Verifica empleados, categorías, productos, áreas, mesas, config, períodos
2. Si faltan datos, ejecuta el seed automáticamente
3. Retorna código 0 si todo está bien

## Modelos OpenCode Disponibles

### GLM-4.7 Free (Recomendado)

- **Modelo:** `opencode/glm-4.7-free`
- **Tipo:** Cloud (gratis)
- **Ventajas:** Rápido, sin necesidad de Ollama local, contexto amplio
- **Uso:** Ideal para análisis de código y revisiones

### Otros Modelos Cloud

- `opencode/*` - Todos los modelos OpenCode cloud
- Consulta `opencode run --help` para más opciones

### Modelos Ollama (Local)

- `ollama:llama3.1:8b-instruct-q4_K_M` - Llama 3.1 cuantizado
- `ollama:qwen2.5:14b-instruct-q4_K_M` - Qwen 2.5 14B
- Requiere tener Ollama instalado y corriendo

## Reportes de Validación

Los reportes se guardan en: `tmp/validation-reports/`

**Estructura del reporte:**

```markdown
# Reporte de Validación de Cambios Recientes

## 1. Información de Git

- Commits recientes
- Estadísticas de cambios
- Estado actual

## 2. Resultados de Pruebas

- Estado (PASSED/FAILED)
- Duración
- Salida completa

## 3. Análisis con OpenCode AI

- Resumen ejecutivo
- Análisis de cambios críticos
- Diagnóstico de fallos
- Recomendaciones
- Veredicto final
```

## Workflow Recomendado

### Después de hacer cambios importantes:

````bash
# 1. Ejecutar validación completa
bash bin/validate-recent-changes.sh

# 2. Si hay fallos, revisar el reporte
cat tmp/validation-reports/validation_*.md

# 3. Revisar solo la información sin AI
bash bin/collect-validation-info.sh 8 > info.md
opencode run --model opencode/glm-4.7-free --file info.md
``

### Antes de commitear:

```bash
# Validar que no se rompió nada
bash bin/validate-recent-changes.sh 1
````

### Revisión de código automatizada:

```bash
# Revisar cambios de las últimas 24 horas
bash bin/validate-recent-changes.sh 24
```

## Integración con Git Hooks

Puedes agregarlo como pre-commit hook en `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Validar cambios antes de commitear

# Solo validar si hay archivos staged
if ! git diff --cached --quiet; then
    echo "Validando cambios..."
    if ! bash bin/validate-recent-changes.sh 1; then
        echo "❌ La validación falló. Revisa el reporte antes de commitear."
        exit 1
    fi
fi
```

## Troubleshooting

### Error: "opencode: command not found"

**Solución:** Instala OpenCode CLI desde https://opencode.ai

### Error: "Model not found"

**Solución:** Verifica que el modelo esté disponible:

```bash
opencode run --model opencode/glm-4.7-free "test"
```

### Las pruebas fallan aunque el código parece correcto

**Causa común:** Los servicios no están corriendo
**Solución:**

```bash
bash bin/up.sh
bash bin/validate-recent-changes.sh
```

### OpenCode AI no responde

**Causa:** Problema de red o límite de uso del modelo cloud
**Solución:** Intenta con Ollama local:

```bash
bash bin/validate-recent-changes.sh 8 ollama:llama3.1:8b-instruct-q4_K_M
```

## Referencias

- Documentación de OpenCode: https://opencode.ai/docs
- AGENTS.md: Guía de desarrollo y patrones del proyecto
- bin/test-all.sh: Suite completa de pruebas
