#!/usr/bin/env python3
"""
Interactive seed helper for creating test employees and customers.
"""

from __future__ import annotations

import os
import sys
from getpass import getpass


def _load_env_file(path: str) -> None:
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip())


def _prompt_bool(prompt: str, default: bool = False) -> bool:
    suffix = "Y/n" if default else "y/N"
    raw = input(f"{prompt} ({suffix}): ").strip().lower()
    if not raw:
        return default
    return raw in {"y", "yes", "s", "si"}


def _prompt_int(prompt: str, default: int) -> int:
    raw = input(f"{prompt} [{default}]: ").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        print("Valor invalido, usando default.")
        return default


def _prompt_text(prompt: str, default: str) -> str:
    raw = input(f"{prompt} [{default}]: ").strip()
    return raw or default


def _resolve_password() -> str:
    from pronto_shared.validation import validate_password

    default_password = os.getenv("SEED_EMPLOYEE_PASSWORD", "ChangeMe!123")
    use_default = _prompt_bool("Usar contrasena default de seed?", default=True)
    if use_default:
        validate_password(default_password)
        return default_password

    while True:
        password = getpass("Nueva contrasena seed (no se muestra): ").strip()
        if not password:
            print("La contrasena no puede estar vacia.")
            continue
        try:
            validate_password(password)
        except Exception as exc:
            print(f"Contrasena invalida: {exc}")
            continue
        return password


def _choose_role() -> str:
    roles = ["waiter", "chef", "cashier", "admin", "system"]
    print("Roles disponibles:")
    for idx, role in enumerate(roles, start=1):
        print(f"  {idx}. {role}")
    raw = input("Selecciona rol [1]: ").strip()
    if not raw:
        return roles[0]
    try:
        selection = int(raw)
        return roles[selection - 1]
    except Exception:
        print("Seleccion invalida, usando waiter.")
        return "waiter"


def _seed_employees(session) -> None:
    # Import from local helper module instead of seed.py
    sys.path.insert(0, os.path.dirname(__file__))
    from employee_seed_helpers import get_or_create_employee

    if not _prompt_bool("Crear/actualizar empleados?", default=True):
        return

    role = _choose_role()
    count = _prompt_int("Cantidad de empleados a crear", 3)
    start_index = _prompt_int("Indice inicial", 1)
    name_prefix = _prompt_text("Prefijo nombre", role.title())
    email_prefix = _prompt_text("Prefijo email", role)
    domain = _prompt_text("Dominio email", "cafeteria.test")
    reset_existing = _prompt_bool("Resetear contrasena en usuarios existentes?", default=False)
    seed_password = _resolve_password()

    created = 0
    for idx in range(start_index, start_index + count):
        name = f"{name_prefix} {idx}"
        email = f"{email_prefix}{idx}@{domain}"
        employee = get_or_create_employee(
            session,
            email,
            name,
            role,
            seed_password,
            force_password_reset=reset_existing,
        )
        if employee:
            created += 1

    print(f"OK Empleados procesados: {created}")


def _seed_customers(session) -> None:
    from pronto_shared.models import Customer
    from pronto_shared.security import hash_identifier

    if not _prompt_bool("Crear/actualizar clientes?", default=True):
        return

    count = _prompt_int("Cantidad de clientes a crear", 5)
    start_index = _prompt_int("Indice inicial", 1)
    name_prefix = _prompt_text("Prefijo nombre cliente", "Cliente")
    email_prefix = _prompt_text("Prefijo email cliente", "cliente")
    domain = _prompt_text("Dominio email", "cafeteria.test")
    phone_prefix = _prompt_text("Prefijo telefono (vacio para omitir)", "")
    update_existing = _prompt_bool("Actualizar nombres si ya existe?", default=True)

    created = 0
    for idx in range(start_index, start_index + count):
        name = f"{name_prefix} {idx}"
        email = f"{email_prefix}{idx}@{domain}"
        email_hash = hash_identifier(email)
        customer = session.query(Customer).filter(Customer.email_hash == email_hash).one_or_none()
        if customer:
            if update_existing:
                customer.name = name
            created += 1
            continue

        customer = Customer()
        customer.name = name
        customer.email = email
        if phone_prefix:
            customer.phone = f"{phone_prefix}{idx}"
        session.add(customer)
        created += 1

    print(f"OK Clientes procesados: {created}")


def main() -> None:
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    sys.path.insert(0, os.path.join(repo_root, "build"))

    # Load envs for encryption + hashing + seed defaults
    _load_env_file(os.path.join(repo_root, "config", "secrets.env"))
    _load_env_file(os.path.join(repo_root, "config", "general.env"))
    _load_env_file(os.path.join(repo_root, "scripts", "init", "seed.env"))

    os.environ.setdefault("SECRET_KEY", "change-me-please")
    os.environ.setdefault("PASSWORD_HASH_SALT", "default-salt")
    os.environ.setdefault("POSTGRES_HOST", "localhost")
    os.environ.setdefault("POSTGRES_PORT", "5432")
    os.environ.setdefault("POSTGRES_USER", "pronto")
    os.environ.setdefault("POSTGRES_PASSWORD", "pronto123")
    os.environ.setdefault("POSTGRES_DB", "pronto")
    os.environ.setdefault("POSTGRES_SSLMODE", "disable")

    from pronto_shared.config import load_config
    from pronto_shared.db import get_session, init_engine
    # Import from local helper module instead of seed.py
    sys.path.insert(0, os.path.dirname(__file__))
    from employee_seed_helpers import assign_missing_employee_identity

    config = load_config("seed-interactive")
    init_engine(config)

    with get_session() as session:
        if _prompt_bool("Completar empleados sin nombre/email?", default=True):
            updated = assign_missing_employee_identity(session)
            print(f"OK Empleados actualizados: {updated}")

        _seed_employees(session)
        _seed_customers(session)


if __name__ == "__main__":
    main()
