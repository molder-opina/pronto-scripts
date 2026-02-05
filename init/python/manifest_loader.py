#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from typing import Any


def die(msg: str, code: int = 1) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(code)


# Supported YAML subset (JSON-compatible):
# - key: scalar
# - key: [a,b,c]
# - key:
#     subkey: scalar
#     subkey: [a,b]
# - key:
#     - name: x
#       table: y
#       columns: [a,b]

_scalar_re = re.compile(r"^(?P<k>[A-Za-z0-9_]+)\s*:\s*(?P<v>.*)\s*$")
_list_re = re.compile(r"^\[(.*)\]$")


def _indent_of(s: str) -> int:
    return len(s) - len(s.lstrip(" "))


def _parse_scalar(v: str) -> Any:
    v = v.strip()
    if v == "" or v.lower() == "null":
        return None
    if v in ("true", "false"):
        return v == "true"
    if re.fullmatch(r"-?\d+", v):
        return int(v)
    if (v.startswith("'") and v.endswith("'")) or (v.startswith('"') and v.endswith('"')):
        return v[1:-1]
    return v


def _parse_list(v: str) -> list[Any]:
    m = _list_re.match(v.strip())
    if not m:
        die(f"manifest.yml: lista invalida: {v!r}")
    inner = m.group(1).strip()
    if inner == "":
        return []
    parts = [p.strip() for p in inner.split(",")]
    return [_parse_scalar(p) for p in parts]


def parse_manifest_strict(path: str) -> dict[str, Any]:
    if not os.path.exists(path):
        die(f"manifest_loader: no existe {path}")

    raw = open(path, "r", encoding="utf-8").read().splitlines()

    data: dict[str, Any] = {}
    i = 0
    n = len(raw)

    while i < n:
        line = raw[i].rstrip("\n")
        i += 1

        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if "\t" in line:
            die("manifest.yml: tabs no permitidos")

        if _indent_of(line) != 0:
            die(f"manifest.yml: indentacion inesperada en top-level: {line!r}")

        m = _scalar_re.match(line)
        if not m:
            die(f"manifest.yml: linea invalida: {line!r}")

        key = m.group("k")
        val = m.group("v").strip()

        if val != "":
            data[key] = _parse_list(val) if _list_re.match(val) else _parse_scalar(val)
            continue

        # block
        block: list[str] = []
        while i < n:
            nxt = raw[i].rstrip("\n")
            if not nxt.strip() or nxt.lstrip().startswith("#"):
                i += 1
                continue
            if _indent_of(nxt) == 0:
                break
            block.append(nxt.rstrip())
            i += 1

        if not block:
            data[key] = {}
            continue

        # list-of-maps
        if block[0].lstrip().startswith("-"):
            lst: list[dict[str, Any]] = []
            j = 0
            while j < len(block):
                ln = block[j]
                if not ln.lstrip().startswith("-"):
                    die(f"manifest.yml: item invalido bajo {key}: {ln!r}")
                ln2 = ln.lstrip()[1:].strip()
                if ln2.startswith(" "):
                    ln2 = ln2.strip()
                m2 = _scalar_re.match(ln2)
                if not m2:
                    die(f"manifest.yml: item invalido bajo {key}: {ln!r}")
                item: dict[str, Any] = {}
                v2 = m2.group("v").strip()
                item[m2.group("k")] = _parse_list(v2) if _list_re.match(v2) else _parse_scalar(v2)
                j += 1
                while j < len(block) and not block[j].lstrip().startswith("-"):
                    prop = block[j].strip()
                    m3 = _scalar_re.match(prop)
                    if not m3:
                        die(f"manifest.yml: propiedad invalida bajo {key}: {block[j]!r}")
                    v3 = m3.group("v").strip()
                    item[m3.group("k")] = _parse_list(v3) if _list_re.match(v3) else _parse_scalar(v3)
                    j += 1
                lst.append(item)
            data[key] = lst
            continue

        # mapping
        mp: dict[str, Any] = {}
        for ln in block:
            if _indent_of(ln) < 2:
                die(f"manifest.yml: indent invalido bajo {key}: {ln!r}")
            prop = ln.strip()
            m2 = _scalar_re.match(prop)
            if not m2:
                die(f"manifest.yml: mapeo invalido bajo {key}: {ln!r}")
            sv = m2.group("v").strip()
            if sv == "":
                die(f"manifest.yml: mapeo anidado no permitido bajo {key}.{m2.group('k')}")
            mp[m2.group("k")] = _parse_list(sv) if _list_re.match(sv) else _parse_scalar(sv)
        data[key] = mp

    return data


def _run(cmd: list[str]) -> tuple[int, str, str]:
    p = subprocess.run(cmd, text=True, capture_output=True)
    return p.returncode, p.stdout, p.stderr


def run_psql(database_url: str, sql: str, search_path: str) -> list[str]:
    # Read-only queries only; use -X to not load ~/.psqlrc
    full_sql = f"SET search_path TO {search_path};\n{sql}"
    cmd = ["psql", database_url, "-X", "-A", "-t", "-q", "-v", "ON_ERROR_STOP=1", "-c", full_sql]
    rc, out, err = _run(cmd)
    if rc != 0:
        die(f"psql error:\n{err.strip()}")
    out = out.strip("\n")
    if out == "":
        return []
    return [ln for ln in out.splitlines() if ln.strip()]


def check_postgres_major(database_url: str, expected_major: int) -> list[str]:
    out = run_psql(database_url, "SHOW server_version_num;", "public")
    if not out:
        return ["server_version_num vacio"]
    try:
        ver_num = int(out[0])
    except ValueError:
        return [f"server_version_num invalido: {out[0]!r}"]
    major = ver_num // 10000
    if major != expected_major:
        return [f"PostgreSQL major invalido: esperado {expected_major}, encontrado {major} (server_version_num={ver_num})"]
    return []


def main() -> None:
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    manifest_default = os.path.join(repo_root, "pronto-scripts", "init", "manifest.yml")
    migrate_script = os.path.join(repo_root, "pronto-scripts", "bin", "pronto-migrate")

    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", required=True)
    ap.add_argument("--manifest", default=manifest_default)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    database_url = os.environ.get("DATABASE_URL", "")
    if not database_url:
        die("manifest_loader: DATABASE_URL no definido")

    manifest = parse_manifest_strict(args.manifest)

    schema = str(manifest.get("schema", "public"))
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", schema):
        die(f"manifest.yml: schema invalido: {schema!r}")

    search_path = str(manifest.get("search_path", schema))
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", search_path):
        die(f"manifest.yml: search_path invalido: {search_path!r}")

    payload: dict[str, Any] = {
        "ok": True,
        "manifest_path": args.manifest,
        "schema": schema,
        "search_path": search_path,
        "postgres_check_errors": [],
        "gaps_schema": [],
        "gaps_extensions": [],
        "gaps_tables": [],
        "gaps_columns": [],
        "gaps_indexes": [],
        "pronto_migrate_check": {"returncode": 0, "output": ""},
    }

    expected_major = int(manifest.get("postgres_major", 16))
    payload["postgres_check_errors"] = check_postgres_major(database_url, expected_major)

    # schemas
    min_schemas = manifest.get("min_schemas") or []
    existing_schemas = set(run_psql(database_url, "SELECT nspname FROM pg_namespace;", search_path))
    for s in min_schemas:
        if str(s) not in existing_schemas:
            payload["gaps_schema"].append(str(s))

    # extensions
    min_ext = manifest.get("min_extensions") or []
    existing_ext = set(run_psql(database_url, "SELECT extname FROM pg_extension;", search_path))
    for e in min_ext:
        if str(e) not in existing_ext:
            payload["gaps_extensions"].append(str(e))

    # tables
    min_tables = manifest.get("min_tables") or {}
    existing_tables = set(
        run_psql(
            database_url,
            f"SELECT table_name FROM information_schema.tables WHERE table_schema='{schema}';",
            search_path,
        )
    )
    if isinstance(min_tables, dict):
        for tname, cols in min_tables.items():
            tname_s = str(tname)
            if tname_s not in existing_tables:
                payload["gaps_tables"].append(tname_s)
                continue
            existing_cols = set(
                run_psql(
                    database_url,
                    f"SELECT column_name FROM information_schema.columns WHERE table_schema='{schema}' AND table_name='{tname_s}';",
                    search_path,
                )
            )
            for c in cols:
                c_s = str(c)
                if c_s not in existing_cols:
                    payload["gaps_columns"].append(f"{tname_s}.{c_s}")

    # indexes by name
    existing_indexes = set(
        run_psql(database_url, f"SELECT indexname FROM pg_indexes WHERE schemaname='{schema}';", search_path)
    )
    min_indexes = manifest.get("min_indexes") or []
    if isinstance(min_indexes, list):
        for it in min_indexes:
            if not isinstance(it, dict):
                continue
            name = it.get("name")
            if name and str(name) not in existing_indexes:
                payload["gaps_indexes"].append(str(name))

    # migrations check (strict)
    if not os.path.exists(migrate_script):
        payload["pronto_migrate_check"] = {"returncode": 1, "output": f"missing {migrate_script}"}
    else:
        rc, out, err = _run([migrate_script, "--check"])
        payload["pronto_migrate_check"] = {"returncode": rc, "output": (out + "\n" + err).strip()}

    payload["ok"] = (
        not payload["postgres_check_errors"]
        and not payload["gaps_schema"]
        and not payload["gaps_extensions"]
        and not payload["gaps_tables"]
        and not payload["gaps_columns"]
        and not payload["gaps_indexes"]
        and payload["pronto_migrate_check"]["returncode"] == 0
    )

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        if payload["ok"]:
            print("OK: manifest + postgres_major + migrations check")
        else:
            print("FAIL")
            if payload["postgres_check_errors"]:
                print(f"postgres_check_errors={payload['postgres_check_errors']}")
            if payload["gaps_schema"]:
                print(f"gaps_schema={payload['gaps_schema']}")
            if payload["gaps_extensions"]:
                print(f"gaps_extensions={payload['gaps_extensions']}")
            if payload["gaps_tables"]:
                print(f"gaps_tables={payload['gaps_tables']}")
            if payload["gaps_columns"]:
                print(f"gaps_columns={payload['gaps_columns']}")
            if payload["gaps_indexes"]:
                print(f"gaps_indexes={payload['gaps_indexes']}")
            if payload["pronto_migrate_check"]["returncode"] != 0:
                print(f"pronto_migrate_check={payload['pronto_migrate_check']['output']}")

    raise SystemExit(0 if payload["ok"] else 1)


if __name__ == "__main__":
    main()
