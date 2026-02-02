#!/usr/bin/env python3
"""
Script para refactorizar referencias a Flask Session por JWT en archivos Python.

Este script:
1. Busca todos los archivos con session.get("employee_id") o session.get("active_scope")
2. Actualiza los imports
3. Reemplaza las referencias con las funciones JWT correctas
4. Genera un reporte de cambios

Uso:
    python bin/python/refactor-session-to-jwt.py [--dry-run] [--file FILE]
"""

import os
import re
import sys
from pathlib import Path

# Add project to path
project_root = Path(__file__).parent.parent
# Ensure pronto_shared is importable
try:
    import pronto_shared
except ImportError:
    raise ImportError("pronto_shared package not found. Install it from pronto-libs repo:
    cd ../pronto-libs && pip install -e .")


def find_files_with_session_refs(base_dir):
    """Encuentra archivos Python con referencias a session.get()"""
    files_with_refs = []

    for root, dirs, files in os.walk(base_dir):
        # Skip __pycache__ and test directories
        dirs[:] = [d for d in dirs if d not in ["__pycache__", ".pytest_cache", "node_modules"]]

        for file in files:
            if file.endswith(".py"):
                filepath = Path(root) / file
                try:
                    content = filepath.read_text()
                    if (
                        'session.get("employee_id")' in content
                        or 'session.get("active_scope")' in content
                    ):
                        files_with_refs.append(filepath)
                except Exception as e:
                    print(f"⚠️  Error reading {filepath}: {e}")

    return files_with_refs


def refactor_file(filepath, dry_run=False):
    """Refactoriza un archivo para usar JWT en lugar de Flask session"""
    content = filepath.read_text()
    original_content = content
    changes = []

    # 1. Actualizar imports
    if "from flask import" in content and ", session" in content:
        # Remover session de los imports de Flask
        content = re.sub(r"from flask import ([^\\n]+), session", r"from flask import \1", content)
        content = re.sub(r"from flask import session, ([^\\n]+)", r"from flask import \1", content)
        content = re.sub(
            r"from flask import session$", r"from flask import request", content, flags=re.MULTILINE
        )
        changes.append("Removed 'session' from Flask imports")

    # 2. Agregar imports de JWT si no existen
    if "from pronto_shared.jwt_middleware import" not in content:
        # Buscar la línea de imports de pronto_employees.decorators
        if "from pronto_employees.decorators import" in content:
            content = re.sub(
                r"(from pronto_employees\.decorators import [^\\n]+)",
                r"\1\nfrom pronto_shared.jwt_middleware import get_current_user, get_employee_id",
                content,
            )
            changes.append("Added JWT middleware imports")
        elif "from shared" in content:
            # Agregar después del primer import de shared
            content = re.sub(
                r"(from shared\.[^\\n]+ import [^\\n]+)",
                r"\1\nfrom pronto_shared.jwt_middleware import get_current_user, get_employee_id",
                content,
                count=1,
            )
            changes.append("Added JWT middleware imports after shared imports")

    # 3. Reemplazar session.get("employee_id") con get_employee_id()
    if 'session.get("employee_id")' in content:
        content = content.replace('session.get("employee_id")', "get_employee_id()")
        changes.append("Replaced session.get('employee_id') with get_employee_id()")

    # 4. Reemplazar session.get("active_scope") con get_current_user().get("active_scope")
    if 'session.get("active_scope"' in content:
        # Necesitamos ser más cuidadosos aquí
        # Patrón: actor_scope = session.get("active_scope", "default")
        pattern = r'(\w+)\s*=\s*session\.get\("active_scope",\s*"([^"]+)"\)'

        def replace_active_scope(match):
            var_name = match.group(1)
            default_value = match.group(2)
            return f'user = get_current_user()\n    {var_name} = user.get("active_scope", "{default_value}")'

        content = re.sub(pattern, replace_active_scope, content)
        changes.append(
            "Replaced session.get('active_scope') with get_current_user().get('active_scope')"
        )

    # 5. Verificar si hubo cambios
    if content != original_content:
        if not dry_run:
            filepath.write_text(content)
            return True, changes
        else:
            return True, changes

    return False, []


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Refactor Flask session to JWT")
    parser.add_argument(
        "--dry-run", action="store_true", help="Show what would be changed without modifying files"
    )
    parser.add_argument("--file", type=str, help="Refactor a specific file")
    parser.add_argument(
        "--dir",
        type=str,
        default="src/pronto_employees",
        help="Directory to search (default: src/pronto_employees)",
    )

    args = parser.parse_args()

    print("╔═══════════════════════════════════════════════════════════╗")
    print("║                                                           ║")
    print("║   🔄 REFACTORIZACIÓN: Flask Session → JWT                ║")
    print("║                                                           ║")
    print("╚═══════════════════════════════════════════════════════════╝")
    print()

    if args.dry_run:
        print("🔍 Modo DRY RUN - No se modificarán archivos")
        print()

    if args.file:
        files_to_process = [Path(args.file)]
    else:
        base_dir = project_root / args.dir
        print(f"📂 Buscando archivos en: {base_dir}")
        files_to_process = find_files_with_session_refs(base_dir)
        print(f"   Encontrados: {len(files_to_process)} archivos")
        print()

    modified_count = 0
    skipped_count = 0

    for filepath in files_to_process:
        relative_path = filepath.relative_to(project_root)
        modified, changes = refactor_file(filepath, dry_run=args.dry_run)

        if modified:
            modified_count += 1
            status = "🔍 WOULD MODIFY" if args.dry_run else "✅ MODIFIED"
            print(f"{status}: {relative_path}")
            for change in changes:
                print(f"   - {change}")
            print()
        else:
            skipped_count += 1

    print()
    print("╔═══════════════════════════════════════════════════════════╗")
    print("║                                                           ║")
    print("║   📊 RESUMEN                                              ║")
    print("║                                                           ║")
    print("╚═══════════════════════════════════════════════════════════╝")
    print()
    print(f"   Archivos modificados: {modified_count}")
    print(f"   Archivos sin cambios: {skipped_count}")
    print(f"   Total procesados: {len(files_to_process)}")
    print()

    if args.dry_run and modified_count > 0:
        print("💡 Ejecuta sin --dry-run para aplicar los cambios")
    elif modified_count > 0:
        print("✅ Refactorización completada")
    else:
        print("ℹ️  No se encontraron archivos para modificar")
    print()


if __name__ == "__main__":
    main()
