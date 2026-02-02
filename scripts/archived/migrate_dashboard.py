import sys
from pathlib import Path

path = Path(
    "/Users/molder/projects/github - molder/pronto-app/build/pronto_employees/templates/dashboard.html"
)

# PTH123: `open()` replaced by `Path.open()`
if path.exists():
    with path.open() as f:
        lines = f.readlines()
else:
    print(f"Error: Path does not exist: {path}")
    sys.exit(1)

# 1. Localizar y extraer bloque Reportes
start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if 'id="reportes"' in line:
        # Buscar el {% if anterior
        for j in range(i, -1, -1):
            if "{% if employee_role" in lines[j]:
                start_idx = j
                break
        break

if start_idx != -1:
    # Buscar el final. El bloque reportes termina antes del bloque "Global notifications panel"
    for i in range(start_idx + 1, len(lines)):
        if "Global notifications panel" in lines[i]:
            # SIM108: Use ternary operator
            end_idx = i - 1 if "{% endif %}" in lines[i - 1] else i - 2
            break

if start_idx == -1 or end_idx == -1:
    print(f"Error: Could not locate Reportes block. Start: {start_idx}, End: {end_idx}")
    # Fallback debug
    if start_idx != -1:
        print("Lines around start:", lines[start_idx : start_idx + 5])
    # PLR1722: Use `sys.exit()`
    sys.exit(1)

# Extraer líneas
report_content = lines[start_idx:end_idx]  # Todo excepto la última línea híbrida
last_line = lines[end_idx]

# Separar la última línea
params = last_line.split("{% endif %}")
report_content.append(params[0] + "{% endif %}\n")  # Cerramos el bloque extraído
remaining_last_line = params[1] if len(params) > 1 else ""

# SIM108: Use ternary operator
remaining_last_line = "" if remaining_last_line.strip() == "" else params[1]

# Eliminar de la lista
lines[end_idx] = remaining_last_line
lines[start_idx:end_idx] = []  # Borrar el cuerpo

# Unir bloque reportes
report_block_str = "".join(report_content)
# Renombrar grupo
report_block_str = report_block_str.replace(
    'data-menu-group="Reportes"', 'data-menu-group="📊 REPORTES"'
)

# Marketing Block
marketing_block = """
{% if employee_role in ['super_admin', 'admin'] %}
<section class="section" id="marketing" data-menu-title="Marketing" data-menu-group="📊 REPORTES">
  <header class="section__header">
    <h2>📈 Marketing</h2>
    <p>Campañas, mailing y fidelización.</p>
  </header>
  <div class="empty-state">
    <div class="empty-state__icon">📢</div>
    <h3>Sección en construcción</h3>
  </div>
</section>
{% endif %}
"""

# Placeholders faltantes
placeholders = {
    "asignacion-roles": """
{% if employee_role in ['super_admin'] %}
<section class="section" id="role-assignment" data-menu-title="Asignación de Roles" data-menu-group="🛡️ SEGURIDAD">
  <header class="section__header"><h2>🛡️ Asignación de Roles</h2><p>Asigna roles a empleados.</p></header>
  <div class="empty-state"><div class="empty-state__icon">🚧</div><h3>En construcción</h3></div>
</section>
{% endif %}
""",
    "especiales": """
{% if employee_role in ['super_admin', 'admin', 'waiter'] %}
<section class="section" id="recommendations" data-menu-title="Recomendaciones" data-menu-group="Especiales">
  <header class="section__header"><h2>✨ Recomendaciones</h2></header>
  <div class="empty-state"><h3>Próximamente</h3></div>
</section>
<section class="section" id="promotions" data-menu-title="Promociones" data-menu-group="Especiales">
  <header class="section__header"><h2>🏷️ Promociones</h2></header>
  <div class="empty-state"><h3>Próximamente</h3></div>
</section>
<section class="section" id="discounts" data-menu-title="Códigos de Descuento" data-menu-group="Especiales">
  <header class="section__header"><h2>🎟️ Códigos</h2></header>
  <div class="empty-state"><h3>Próximamente</h3></div>
</section>
{% endif %}
""",
    "admin-extras": """
{% if employee_role in ['super_admin', 'admin'] %}
<section class="section" id="anonymous-sessions-ph" data-menu-title="Sesiones Anónimas" data-menu-group="Administración">
   <header class="section__header"><h2>🕵️ Sesiones Anónimas</h2></header><div class="empty-state"><h3>Próximamente</h3></div>
</section>
<section class="section" id="clients-ph" data-menu-title="Clientes" data-menu-group="Administración">
   <header class="section__header"><h2>👥 Clientes</h2></header><div class="empty-state"><h3>Próximamente</h3></div>
</section>
{% endif %}
""",
}

# 2. Insertar después de Caja (antes de Menu)
insert_pos = -1
for i, line in enumerate(lines):
    if 'id="menu"' in line:
        for j in range(i, -1, -1):
            if "{% if" in lines[j]:
                insert_pos = j
                break
        break

if insert_pos != -1:
    lines.insert(insert_pos, report_block_str + "\n" + marketing_block + "\n")

    # Mapeamos los renombres en todo el archivo
    new_lines = []
    for line in lines:
        # E741: Ambiguous variable name: `l`
        line_content = line
        if (
            'id="panel-meseros"' in line_content
            or 'id="panel-cocina"' in line_content
            or 'id="caja"' in line_content
        ):
            line_content = line_content.replace(
                'data-menu-group="Módulos"', 'data-menu-group="🏠 OPERACIÓN"'
            )

        if 'data-menu-group="Seguridad"' in line_content:
            line_content = line_content.replace(
                'data-menu-group="Seguridad"', 'data-menu-group="🛡️ SEGURIDAD"'
            )

        if 'data-menu-group="Branding"' in line_content:
            line_content = line_content.replace(
                'data-menu-group="Branding"', 'data-menu-group="🎨 Branding"'
            )

        if 'data-menu-group="Configuración"' in line_content:
            line_content = line_content.replace(
                'data-menu-group="Configuración"', 'data-menu-group="⚙️ Configuración"'
            )

        new_lines.append(line_content)

    lines = new_lines

    # B007: Loop control variable `i` not used within loop body
    for line in lines:
        if 'id="aditamentos"' in line:
            # Logic would go here
            break

    # Escribir el archivo
    with path.open("w") as f:
        f.writelines(lines)
else:
    print("Error: Could not find insert position (menu)")
    sys.exit(1)

print("Migration successful")
