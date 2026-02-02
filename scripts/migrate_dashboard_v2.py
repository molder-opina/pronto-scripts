from pathlib import Path

path = Path(
    "/Users/molder/projects/github - molder/pronto-app/src/pronto_employees/templates/dashboard.html"
)


def extract_block(lines, id_search):
    start = -1
    end = -1
    for i, line in enumerate(lines):
        if id_search in line:
            # Buscar if hacia atras
            for j in range(i, -1, -1):
                if "{% if" in lines[j]:
                    start = j
                    break
            break

    if start != -1:
        # Buscar end. Buscamos el siguiente bloque o un endif que cierra.
        balance = 0
        for k in range(start, len(lines)):
            if "{% if" in lines[k]:
                balance += 1
            if "{% endif %}" in lines[k]:
                balance -= 1
                if balance == 0:
                    end = k
                    break

    if start != -1 and end != -1:
        block = lines[start : end + 1]
        lines[start : end + 1] = []
        return block
    return None


if path.exists():
    with path.open() as f:
        lines = f.readlines()

    # 1. Mover Sesiones (Session Management)
    session_block = extract_block(lines, 'id="session-management"')
    if session_block:
        print("Extracted Session Management")

    # 2. Mover Clientes
    clients_block = extract_block(lines, 'id="clientes"')
    if clients_block:
        print("Extracted Clientes")

    # 3. Preparar bloques nuevos
    anonymous_sessions_block = """
{% if employee_role in ['super_admin', 'admin'] %}
<section class="section" id="anonymous-sessions" data-menu-title="Sesiones Anónimas" data-menu-group="Administración">
   <header class="section__header"><h2>🕵️ Sesiones Anónimas</h2><p>Gestiona sesiones sin registro.</p></header>
   <div class="empty-state"><div class="empty-state__icon">🚧</div><h3>En construcción</h3></div>
</section>
{% endif %}
\n"""

    specials_block = """
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
\n"""

    # 4. Insertar Administración (Sesiones, Clientes, Anónimas) antes de Empleados
    insert_idx = -1
    for i, line in enumerate(lines):
        if 'id="empleados-section"' in line:
            # Buscar if anterior
            for j in range(i, -1, -1):
                if "{% if" in lines[j]:
                    insert_idx = j
                    break
            break

    if insert_idx != -1:
        to_insert = []
        if session_block:
            to_insert.extend(session_block)
        to_insert.append("\n")
        to_insert.append(anonymous_sessions_block)
        if clients_block:
            to_insert.extend(clients_block)
        to_insert.append("\n")

        lines[insert_idx:insert_idx] = to_insert
        print("Inserted Admin blocks")
    else:
        print("Error: Employees section not found")

    # 5. Insertar Especiales despues de Aditamentos
    adit_idx = -1
    for i, line in enumerate(lines):
        if 'id="aditamentos"' in line:
            adit_idx = i
            break

    if adit_idx != -1:
        next_section_idx = -1
        for k in range(adit_idx + 1, len(lines)):
            if "<section" in lines[k]:
                # Encontramos la siguiente.
                for j in range(k, -1, -1):
                    if "{% if" in lines[j]:
                        next_section_idx = j
                        break
                break
            if k > adit_idx + 500:
                break  # Safety

        if next_section_idx != -1:
            lines.insert(next_section_idx, specials_block)
            print("Inserted Specials block")
        else:
            # Fallback
            print("Warning: Could not find next section after aditamentos. Inserting at end.")
            lines.insert(adit_idx + 2, specials_block)

    # Guardar
    with path.open("w") as f:
        f.writelines(lines)
else:
    print(f"Error: Path does not exist: {path}")
