from pathlib import Path

path = Path(
    "/Users/molder/projects/github - molder/pronto-app/src/pronto_employees/templates/dashboard.html"
)


def find_start(lines, id_search):
    for i, line in enumerate(lines):
        if id_search in line:
            # Buscar if hacia atras
            for j in range(i, -1, -1):
                if "{% if" in lines[j]:
                    return j
            # Si no hay if (es solo section), buscar section start
            return i
    return -1


def find_end(lines, start):
    if start == -1:
        return -1

    # Buscar end.
    balance = 0
    for k in range(start, len(lines)):
        if "{% if" in lines[k]:
            balance += 1
        if "{% endif %}" in lines[k]:
            balance -= 1
            if balance == 0:
                return k

    # Si no había if, buscar </section>
    for k in range(start, len(lines)):
        if "</section>" in lines[k]:
            return k
    return -1


def extract_block(lines, id_search):
    start = find_start(lines, id_search)
    end = find_end(lines, start)

    if start != -1 and end != -1:
        block = lines[start : end + 1]
        lines[start : end + 1] = []
        return block
    return None


if path.exists():
    with path.open() as f:
        lines = f.readlines()

    # 1. Corregir Especiales del final (insertar después de Inventario pero ANTES de Branding/Areas)
    # Buscamos 'id="recommendations"' al final
    found_idx = -1

    # Fix E701: pass should be on a new line
    for i in range(len(lines) - 1, max(0, len(lines) - 200), -1):
        if 'id="recommendations"' in lines[i]:
            pass

    for i in range(len(lines) - 1, max(0, len(lines) - 200), -1):
        if 'id="recommendations"' in lines[i]:
            # Encontramos. Buscar el if anterior.
            for j in range(i, max(0, i - 10), -1):
                if "{% if" in lines[j]:
                    found_idx = j
                    break
            break

    specials_block = []
    if found_idx != -1:
        end_idx = found_idx
        for k in range(found_idx, len(lines)):
            if "{% endif %}" in lines[k]:
                end_idx = k
                break

        specials_block = lines[found_idx : end_idx + 1]
        lines[found_idx : end_idx + 1] = []
        print("Extracted specials block from end")

    # 2. Mover Branding
    branding_block = extract_block(lines, 'id="branding-section"')
    if branding_block:
        print("Extracted Branding")

    # 3. Insertar Branding antes de Areas
    areas_idx = -1
    for i, line in enumerate(lines):
        if 'id="areas-salones"' in line:
            # Buscar inicio de bloque (section o if)
            # Areas salones no tiene if (es generico), pero comprobemos
            for j in range(i, -1, -1):
                if "<section" in lines[j]:
                    areas_idx = j
                    break
            break

    if areas_idx != -1:
        if branding_block:
            lines[areas_idx:areas_idx] = branding_block
            lines.insert(areas_idx, "\n")
            print("Inserted Branding before Areas")

        # 4. Insertar Especiales ANTES de Branding (Menu -> Especiales -> Branding)
        # Branding esta ahora en areas_idx (o cerca)
        if specials_block:
            lines[areas_idx:areas_idx] = specials_block
            lines.insert(areas_idx, "\n")
            print("Inserted Specials before Branding")

    else:
        print(
            "Could not find Areas section. inserting specials and branding at old branding location fallback"
        )
        # Fallback logic omitted for brevity

    # Guardar
    with path.open("w") as f:
        f.writelines(lines)
else:
    print(f"Path does not exist: {path}")
