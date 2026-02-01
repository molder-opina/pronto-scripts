from pathlib import Path

path = Path(
    "/Users/molder/projects/github - molder/pronto-app/src/employees_app/templates/dashboard.html"
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

    security_1 = extract_block(lines, 'id="employee-roles"')
    security_2 = extract_block(lines, 'id="role-permissions"')

    if security_1 and security_2:
        # Buscar custom-roles
        insert_idx = -1
        for i, line in enumerate(lines):
            if 'id="custom-roles"' in line:
                for j in range(i, -1, -1):
                    if "{% if" in lines[j]:
                        insert_idx = j
                        break
                break

        if insert_idx != -1:
            # Fix RUF005: Consider `[*security_1, '\n', *security_2, '\n']` instead of concatenation
            lines[insert_idx:insert_idx] = [*security_1, "\n", *security_2, "\n"]
            print("Moved Security blocks before Custom Roles")
        else:
            print("Could not find Custom Roles section")
    else:
        print("Could not find Security blocks (maybe already moved? or regex mismatch)")

    with path.open("w") as f:
        f.writelines(lines)
else:
    print(f"Path does not exist: {path}")
