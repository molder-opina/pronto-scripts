#!/usr/bin/env python3
from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable, Literal

PARITY_CHECK_VERSION = "1.0.0"

Target = Literal["employees", "clients", "api"]
Source = Literal["employees_vue", "employees_jinja", "clients_vue", "clients_jinja"]

UNKNOWN_THRESHOLDS: dict[Source, int] = {
    "employees_vue": 20,
    "employees_jinja": 10,
    "clients_vue": 20,
    "clients_jinja": 10,
}

DEFAULT_BATCH_K = 25


COMMENT_LINE_RE = re.compile(r"^\s*(//|/\*|\*)")

ABS_URL_RE = re.compile(r"https?://(?P<host>[^/]+)(?P<path>/[^ \t\r\n\"'`>]*)")


@dataclasses.dataclass(frozen=True)
class Ref:
    source: Source
    file: str
    line: int


@dataclasses.dataclass
class FrontendEntry:
    refs_count: int = 0
    refs: list[Ref] = dataclasses.field(default_factory=list)


def _realpath(p: str) -> str:
    return os.path.realpath(p)


def detect_repo_root(script_path: str, cli_repo_root: str | None) -> Path:
    if cli_repo_root:
        root = Path(_realpath(cli_repo_root))
    else:
        # bin -> pronto-scripts -> repo
        root = Path(_realpath(str(Path(script_path).parent.parent.parent)))

    expected = [
        root / "AGENTS.md",
        root / "pronto-scripts",
        root / "pronto-static",
    ]
    present = sum(1 for p in expected if p.exists())
    if present < 2:
        raise RuntimeError(
            f"repo_root invalido: {root}. "
            f"Se requieren al menos 2 de: AGENTS.md, pronto-scripts/, pronto-static/. "
            f"Pasa --repo-root."
        )

    return root


def _git_commit(repo_root: Path) -> str:
    try:
        out = subprocess.check_output(
            ["git", "-C", str(repo_root), "rev-parse", "--short", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        return out
    except Exception:
        return "UNKNOWN"


def _utc_now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _strip_trailing_slash(path: str) -> str:
    if path != "/" and path.endswith("/"):
        return path[:-1]
    return path


def normalize_path(path: str) -> str:
    # 1) ${...} -> {var}
    path = re.sub(r"\$\{[^}]+\}", "{var}", path)
    # 2) %7B...%7D -> {var} (case-insensitive)
    path = re.sub(r"%7B[^%]+%7D", "{var}", path, flags=re.IGNORECASE)
    # 3) ignore querystring
    path = path.split("?", 1)[0]
    # 4) normalize slashes (only within the path)
    path = re.sub(r"//+", "/", path)
    # 5) ensure leading /
    if not path.startswith("/"):
        path = "/" + path
    # 6) trailing slash policy
    path = _strip_trailing_slash(path)
    return path


def _normalize_backend_rule(rule: str) -> str:
    # Convert Flask converters to {var}
    # <int:id> -> {var}, <uuid:id> -> {var}, <id> -> {var}
    rule = re.sub(r"<[^>]+>", "{var}", rule)
    return normalize_path(rule)


def _parse_method(raw: str | None) -> str:
    if not raw:
        return "UNKNOWN"
    m = raw.strip().upper()
    if m in {"GET", "POST", "PUT", "PATCH", "DELETE"}:
        return m
    return "UNKNOWN"


def _extract_query_keys(raw: str) -> list[str]:
    if "?" not in raw:
        return []
    qs = raw.split("?", 1)[1]
    if not qs:
        return []
    keys: list[str] = []
    for part in qs.split("&"):
        if not part:
            continue
        key = part.split("=", 1)[0]
        if key:
            keys.append(key)
    return keys


def _load_simple_yaml(path: Path) -> dict[str, Any]:
    # Minimal YAML subset parser for deterministic configs:
    # - top-level keys
    # - list of scalars (dash items)
    # - list of dicts with scalar values (dash items + indented key: value)
    data: dict[str, Any] = {}
    if not path.exists():
        return data

    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    i = 0
    current_key: str | None = None
    current_list: list[Any] | None = None
    while i < len(lines):
        line = lines[i]
        raw = line.rstrip()
        i += 1
        if not raw or raw.lstrip().startswith("#"):
            continue

        if re.match(r"^[A-Za-z0-9_.-]+:\s*$", raw):
            current_key = raw.split(":", 1)[0].strip()
            current_list = []
            data[current_key] = current_list
            continue

        if current_key is None or current_list is None:
            continue

        m_item = re.match(r"^\s*-\s*(.*)\s*$", raw)
        if not m_item:
            continue

        rest = m_item.group(1).strip()
        if rest and ":" not in rest:
            current_list.append(rest.strip().strip("'\""))
            continue

        item: dict[str, str] = {}
        if rest and ":" in rest:
            k, v = rest.split(":", 1)
            item[k.strip()] = v.strip().strip("'\"")

        # consume indented key: value lines
        while i < len(lines):
            nxt = lines[i]
            if not nxt.strip() or nxt.lstrip().startswith("#"):
                i += 1
                continue
            if re.match(r"^\s*-\s+", nxt):
                break
            if re.match(r"^[A-Za-z0-9_.-]+:\s*$", nxt.strip()):
                break
            m_kv = re.match(r"^\s+([A-Za-z0-9_.-]+):\s*(.*)\s*$", nxt)
            if not m_kv:
                break
            i += 1
            item[m_kv.group(1).strip()] = m_kv.group(2).strip().strip("'\"")

        current_list.append(item)

    return data


def _iter_source_files(repo_root: Path, source: Source) -> list[Path]:
    if source == "employees_vue":
        base = repo_root / "pronto-static" / "src" / "vue" / "employees"
    elif source == "clients_vue":
        base = repo_root / "pronto-static" / "src" / "vue" / "clients"
    elif source == "employees_jinja":
        base = repo_root / "pronto-employees" / "src" / "pronto_employees" / "templates"
    elif source == "clients_jinja":
        base = repo_root / "pronto-client" / "src" / "pronto_clients" / "templates"
    else:
        return []

    if not base.exists():
        return []

    exts = {".ts", ".vue", ".js", ".html"}
    if source.endswith("_jinja"):
        exts = {".html"}

    deny_globs = [
        "**/__tests__/**",
        "**/*.test.*",
        "**/*.spec.*",
        "**/tests/**",
        "**/mocks/**",
        "**/fixtures/**",
        "**/docs/**",
        "**/sample*/**",
    ]

    files: list[Path] = []
    for p in base.rglob("*"):
        if not p.is_file():
            continue
        if p.suffix not in exts:
            continue

        rel = str(p.relative_to(repo_root)).replace(os.sep, "/")
        if rel.startswith("pronto-static/src/static_content/assets/js/"):
            continue

        denied = False
        for g in deny_globs:
            if Path(rel).match(g):
                denied = True
                break
        if denied:
            continue
        files.append(p)

    return files


def _ensure_wrapper_present(repo_root: Path, target: Target) -> dict[str, list[str]]:
    wrappers: dict[str, list[str]] = {}
    if target == "employees":
        wrappers["employees_vue"] = [
            str(repo_root / "pronto-static" / "src" / "vue" / "employees" / "core" / "http.ts"),
        ]
    elif target == "clients":
        wrappers["clients_vue"] = [
            str(repo_root / "pronto-static" / "src" / "vue" / "clients" / "core" / "http.ts"),
        ]
    else:
        return wrappers

    missing: list[str] = []
    for src, paths in wrappers.items():
        for p in paths:
            if not Path(p).exists():
                missing.append(p)

    if missing:
        raise RuntimeError(
            "WRAPPER_NOT_FOUND. Paths buscados:\n"
            + "\n".join(missing)
            + "\nSugerencia: actualiza la lista hardcode/config de wrappers."
        )

    return wrappers


def _scan_frontend_source(
    repo_root: Path,
    source: Source,
    allowlist: dict[str, Any],
) -> tuple[
    dict[str, dict[str, FrontendEntry]],
    dict[str, dict[str, int]],
    list[dict[str, Any]],
    list[dict[str, Any]],
]:
    # returns:
    # - frontend_map[path][method] -> entry
    # - query_keys_used[path][key] -> count
    # - unknown_methods refs
    # - violations
    frontend_map: dict[str, dict[str, FrontendEntry]] = defaultdict(dict)
    query_keys_used: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    unknown_methods: list[dict[str, Any]] = []
    violations: list[dict[str, Any]] = []

    allowed_external = allowlist.get("allow_external", []) if isinstance(allowlist, dict) else []
    allowed_external = allowed_external if isinstance(allowed_external, list) else []

    def _clean_host(host: str) -> str:
        h = (host or "").strip().strip("\"'").strip()
        m = re.match(r"^(?P<h>[A-Za-z0-9.-]+)", h)
        if not m:
            return ""
        return m.group("h").strip().lower()

    def _is_ignored_host(host: str) -> bool:
        # Reduce false positives for namespace URLs and sample placeholders.
        return host in {"www.w3.org", "ejemplo.com", "example.com"}

    def _should_scan_abs_urls(src: Source, raw_line: str) -> bool:
        l = raw_line.lower()
        if "xmlns" in l:
            return False
        if "placeholder=" in l:
            return False
        # Only consider absolute URLs violations when likely used as a resource.
        return ("src=" in l) or ("href=" in l) or ("fetch(" in l) or ("axios" in l)

    def is_external_allowed(host: str, path: str) -> bool:
        host = _clean_host(host)
        if not host or _is_ignored_host(host):
            return True
        for item in allowed_external:
            if not isinstance(item, dict):
                continue
            item_host = _clean_host(item.get("host") or "")
            prefix = (item.get("path_prefix") or "").strip()
            if item_host and item_host == host and path.startswith(prefix):
                return True
        return False

    def _maybe_append_placeholder_for_concat(line: str, lit: str) -> str:
        # Support basic concatenation patterns:
        # "/api/x/" + id  -> "/api/x/{var}"
        # "/api/x/" + id + "/y" -> captures only first segment, still becomes "/api/x/{var}"
        if not lit:
            return lit
        # Avoid changing absolute URLs here.
        if ABS_URL_RE.match(lit):
            return lit
        # Detect if this exact literal is concatenated with + something non-string.
        # Keep it conservative to avoid false positives.
        try:
            if re.search(re.escape(lit) + r"\s*\+\s*[^\"'`]", line):
                if lit.endswith("/"):
                    return lit + "{var}"
                return lit + "/{var}"
        except re.error:
            return lit
        return lit

    files = _iter_source_files(repo_root, source)
    for fp in files:
        try:
            lines = fp.read_text(encoding="utf-8", errors="ignore").splitlines()
        except Exception:
            continue

        in_block_comment = False
        for idx, line in enumerate(lines, start=1):
            raw = line.rstrip("\n")

            if "/*" in raw and "*/" not in raw:
                in_block_comment = True
            if in_block_comment:
                if "*/" in raw:
                    in_block_comment = False
                continue

            if COMMENT_LINE_RE.match(raw):
                continue

            # External absolute URLs
            if _should_scan_abs_urls(source, raw):
                for m in ABS_URL_RE.finditer(raw):
                    host = _clean_host(m.group("host"))
                    if not host or _is_ignored_host(host):
                        continue
                    pth = m.group("path")
                    norm_path = normalize_path(pth)
                    if not is_external_allowed(host, norm_path):
                        violations.append(
                            {
                                "code": "HARD_CODED_EXTERNAL_HOST",
                                "host": host,
                                "path": norm_path,
                                "source": source,
                                "file": str(fp),
                                "line": idx,
                            }
                        )

            if "/api/" not in raw:
                continue

            # Wrapper / fetch / axios method inference (lightweight, string-literal oriented)
            window = "\n".join(lines[idx - 1 : idx - 1 + 12])
            method_match = re.search(
                r"method\s*:\s*['\"](?P<m>[A-Za-z]+)['\"]", window, flags=re.IGNORECASE
            )
            method = _parse_method(method_match.group("m") if method_match else None)

            call_is_wrapper = "requestJSON" in window
            call_is_fetch = re.search(r"\bfetch\s*\(", window) is not None or "new Request" in window
            call_is_axios = re.search(r"\baxios\b", window) is not None

            # Wrapper default method is GET if omitted.
            if call_is_wrapper and method == "UNKNOWN":
                method = "GET"

            # Prefer wrapper/fetch/axios methods, else UNKNOWN.
            if not (call_is_wrapper or call_is_fetch or call_is_axios):
                method = "UNKNOWN"

            # Infer GET for implicit fetch calls (reduce "unknown method" noise)
            if method == "UNKNOWN" and call_is_fetch:
                 method = "GET"

            # Extract string literals containing /api/
            literals: list[str] = []
            for rx in (
                re.compile(r"'(?P<s>[^']*?/api/[^']*)'"),
                re.compile(r"\"(?P<s>[^\"]*?/api/[^\"]*)\""),
                re.compile(r"`(?P<s>[^`]*?/api/[^`]*)`"),
            ):
                for mm in rx.finditer(raw):
                    literals.append(mm.group("s"))

            if not literals:
                continue

            for lit in literals:
                lit = _maybe_append_placeholder_for_concat(raw, lit)

                m_abs = ABS_URL_RE.match(lit)
                if m_abs:
                    host = _clean_host(m_abs.group("host"))
                    pth = m_abs.group("path")
                    norm_path = normalize_path(pth)
                    if not is_external_allowed(host, norm_path):
                        violations.append(
                            {
                                "code": "HARD_CODED_EXTERNAL_HOST",
                                "host": host,
                                "path": norm_path,
                                "source": source,
                                "file": str(fp),
                                "line": idx,
                            }
                        )
                    # Absolute URLs do not participate in /api/* parity comparisons.
                    continue

                # Handle template-host allowlist (e.g. `${FEEDBACK_API_BASE}/api/feedback/bulk`)
                if lit.startswith("${") and "}/" in lit:
                    # Not stable: treat as unknown unless allowlist supports template_var; report violation separately
                    unknown_methods.append(
                        {
                            "source": source,
                            "file": str(fp),
                            "line": idx,
                            "path": lit,
                            "reason": "TEMPLATE_HOST",
                        }
                    )
                    continue

                keys = _extract_query_keys(lit)
                norm_path = normalize_path(lit)

                if norm_path.startswith("/api/"):
                    for k in keys:
                        query_keys_used[norm_path][k] += 1

                    entry = frontend_map[norm_path].get(method)
                    if entry is None:
                        entry = FrontendEntry()
                        frontend_map[norm_path][method] = entry
                    entry.refs_count += 1
                    entry.refs.append(Ref(source=source, file=str(fp), line=idx))

                    if method == "UNKNOWN":
                        unknown_methods.append(
                            {
                                "source": source,
                                "file": str(fp),
                                "line": idx,
                                "path": norm_path,
                            }
                        )

    return frontend_map, query_keys_used, unknown_methods, violations


def _scan_scoped_api_rewrite(repo_root: Path) -> list[dict[str, Any]]:
    violations: list[dict[str, Any]] = []

    scoped_re = re.compile(r"/(waiter|chef|cashier|admin|system)/api/")
    templ_scope_re = re.compile(r"/\\{scope\\}/api/|/\\$\\{scope\\}/api/")

    for fp in _iter_source_files(repo_root, "employees_vue"):
        try:
            lines = fp.read_text(encoding="utf-8", errors="ignore").splitlines()
        except Exception:
            continue

        in_block_comment = False
        for idx, raw in enumerate(lines, start=1):
            line = raw.rstrip("\n")
            if "/*" in line and "*/" not in line:
                in_block_comment = True
            if in_block_comment:
                if "*/" in line:
                    in_block_comment = False
                continue
            if COMMENT_LINE_RE.match(line):
                continue

            if scoped_re.search(line) or templ_scope_re.search(line) or "/api/* to /<scope>/api/*" in line:
                violations.append(
                    {
                        "code": "SCOPED_API_REWRITE",
                        "file": str(fp),
                        "line": idx,
                    }
                )
    return violations


def _scan_credentials_same_origin(repo_root: Path) -> list[dict[str, Any]]:
    violations: list[dict[str, Any]] = []
    roots = [
        repo_root / "pronto-static" / "src" / "vue" / "employees",
        repo_root / "pronto-static" / "src" / "vue" / "clients",
    ]
    for r in roots:
        if not r.exists():
            continue
        for p in r.rglob("*"):
            if not p.is_file():
                continue
            if p.suffix not in {".ts", ".js", ".vue"}:
                continue
            txt = p.read_text(encoding="utf-8", errors="ignore")
            for m in re.finditer(r"credentials\s*:\s*['\"]same-origin['\"]", txt):
                line = txt[: m.start()].count("\n") + 1
                violations.append({"code": "CREDENTIALS_SAME_ORIGIN", "file": str(p), "line": line})
    return violations


def get_backend_map(repo_root: Path, target: Target) -> dict[str, set[str]]:
    env = os.environ.copy()
    env["PRONTO_ROUTES_ONLY"] = "1"

    pythonpath_parts: list[str] = []
    pythonpath_parts.append(str(repo_root / "pronto-libs" / "src"))
    if target == "employees":
        pythonpath_parts.append(str(repo_root / "pronto-employees" / "src"))
        # Also add api_app since we check it now
        pythonpath_parts.append(str(repo_root / "pronto-api" / "src"))
    elif target == "clients":
        pythonpath_parts.append(str(repo_root / "pronto-client" / "src"))
        # Also add api_app
        pythonpath_parts.append(str(repo_root / "pronto-api" / "src"))
    elif target == "api":
        pythonpath_parts.append(str(repo_root / "pronto-api" / "src"))

    env["PYTHONPATH"] = os.pathsep.join(pythonpath_parts)

    code = ""
    # For employees, we check both pronto_employees (frontend host) AND api_app (backend service)
    # because the frontend might hit either (via proxy) or we want to count shared routes.
    if target == "employees":
        code = (
            "import os, sys, json\n"
            "os.environ['PRONTO_ROUTES_ONLY'] = '1'\n"
            "out = {}\n"
            "try:\n"
            "    from pronto_employees.app import create_app as create_emp\n"
            "    app_emp = create_emp()\n"
            "    for rule in app_emp.url_map.iter_rules():\n"
            "        p = rule.rule\n"
            "        if not p.startswith('/api/'): continue\n"
            "        methods = set(rule.methods or set()) - {'HEAD', 'OPTIONS'}\n"
            "        out.setdefault(p, set()).update(methods)\n"
            "except Exception as e: print(f'EMP_ERR: {e}', file=sys.stderr)\n"
            "try:\n"
            "    from api_app.app import create_app as create_api\n"
            "    app_api = create_api()\n"
            "    for rule in app_api.url_map.iter_rules():\n"
            "        p = rule.rule\n"
            "        if not p.startswith('/api/'): continue\n"
            "        methods = set(rule.methods or set()) - {'HEAD', 'OPTIONS'}\n"
            "        out.setdefault(p, set()).update(methods)\n"
            "except Exception as e: print(f'API_ERR: {e}', file=sys.stderr)\n"
        )
    elif target == "clients":
        code = (
            "from pronto_clients.app import create_app as create_client\n"
            "from api_app.app import create_app as create_api\n"
            "app_client = create_client()\n"
            "app_api = create_api()\n"
            "out = {}\n"
            # Client routes
            "for rule in app_client.url_map.iter_rules():\n"
            "    p = rule.rule\n"
            "    if not p.startswith('/api/'): continue\n"
            "    methods = set(rule.methods or set()) - {'HEAD', 'OPTIONS'}\n"
            "    out.setdefault(p, set()).update(methods)\n"
            # API routes
            "for rule in app_api.url_map.iter_rules():\n"
            "    p = rule.rule\n"
            "    if not p.startswith('/api/'): continue\n"
            "    methods = set(rule.methods or set()) - {'HEAD', 'OPTIONS'}\n"
            "    out.setdefault(p, set()).update(methods)\n"
        )
    else:
        code = "from api_app.app import create_app\napp=create_app()\n"
        code += (
            "out={}\n"
            "for rule in app.url_map.iter_rules():\n"
            "    p=rule.rule\n"
            "    if not p.startswith('/api/'):\n"
            "        continue\n"
            "    methods=set(rule.methods or set())\n"
            "    methods=methods - {'HEAD','OPTIONS'}\n"
            "    out.setdefault(p, set()).update(methods)\n"
        )

    code += (
        "out={k: sorted(v) for k,v in out.items()}\n"
        "import json\n"
        "print(json.dumps(out))\n"
    )

    raw = subprocess.check_output([sys.executable, "-c", code], env=env, text=True)
    parsed = json.loads(raw)

    backend_map: dict[str, set[str]] = {}
    for rule, methods in parsed.items():
        norm = _normalize_backend_rule(rule)
        backend_map.setdefault(norm, set()).update({m.upper() for m in methods})
    return backend_map


def routes_only_check(repo_root: Path, target: Target) -> dict[str, Any]:
    try:
        backend_map = get_backend_map(repo_root, target)
        sample = sorted(backend_map.keys())[:20]
        return {"ok": True, "count": len(backend_map), "sample": sample}
    except Exception as e:
        import traceback
        return {"ok": False, "error": str(e), "stack": traceback.format_exc()}


def parity_check(
    repo_root: Path,
    target: Target,
    show_extra: bool,
    fail_on_extra: bool,
    batch_pin: list[str],
    write_snapshot: bool,
) -> tuple[dict[str, Any], int]:
    if target not in {"employees", "clients"}:
        return {"ok": False, "error": "target invalido"}, 1

    _ensure_wrapper_present(repo_root, target)

    allowlist = _load_simple_yaml(repo_root / "pronto-ai" / "parity-check.allowlist.yml")
    denylist = _load_simple_yaml(repo_root / "pronto-ai" / "parity-check.backend_denylist.yml")
    deny_prefixes = denylist.get("deny_prefixes", []) if isinstance(denylist, dict) else []
    deny_prefixes = deny_prefixes if isinstance(deny_prefixes, list) else []

    sources: list[Source] = (
        ["employees_vue", "employees_jinja"] if target == "employees" else ["clients_vue", "clients_jinja"]
    )

    sources_scanned: dict[str, dict[str, int]] = {}
    frontend_map: dict[str, dict[str, FrontendEntry]] = defaultdict(dict)
    query_keys_used: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    unknown_methods: list[dict[str, Any]] = []
    violations: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []

    for src in sources:
        files = _iter_source_files(repo_root, src)
        sources_scanned[src] = {"files": len(files)}
        fm, qk, unk, v = _scan_frontend_source(repo_root, src, allowlist)

        for path, methods in fm.items():
            for method, entry in methods.items():
                dst = frontend_map[path].get(method)
                if dst is None:
                    dst = FrontendEntry()
                    frontend_map[path][method] = dst
                dst.refs_count += entry.refs_count
                dst.refs.extend(entry.refs)

        for p, keys in qk.items():
            for k, c in keys.items():
                query_keys_used[p][k] += c

        unknown_methods.extend(unk)
        violations.extend(v)

    violations.extend(_scan_scoped_api_rewrite(repo_root))
    violations.extend(_scan_credentials_same_origin(repo_root))

    # Unknown-methods warning thresholds by source (non-blocking)
    unknown_by_source: dict[str, int] = defaultdict(int)
    for u in unknown_methods:
        src = u.get("source")
        if isinstance(src, str):
            unknown_by_source[src] += 1
    for src, threshold in UNKNOWN_THRESHOLDS.items():
        count = int(unknown_by_source.get(src, 0))
        if count > threshold:
            warnings.append(
                {
                    "code": "UNKNOWN_METHODS_THRESHOLD",
                    "source": src,
                    "count": count,
                    "threshold": threshold,
                }
            )

    # Backend introspection
    ro = routes_only_check(repo_root, target)
    if not ro.get("ok"):
        return {"ok": False, "error": "routes-only-check failed", "details": ro}, 1

    backend_map = get_backend_map(repo_root, target)

    # Apply backend denylist for EXTRA reporting only (does not affect MISSING).
    def is_denied_backend(path: str) -> bool:
        return any(path.startswith(prefix) for prefix in deny_prefixes)

    missing_known: list[dict[str, Any]] = []
    missing_unknown: list[dict[str, Any]] = []
    method_mismatch: list[dict[str, Any]] = []
    extra: list[dict[str, Any]] = []

    # Compare
    for path, by_method in sorted(frontend_map.items()):
        backend_methods = backend_map.get(path, set())

        for method, entry in sorted(by_method.items()):
            if method == "UNKNOWN":
                if not backend_methods:
                    missing_unknown.append(
                        {
                            "path": path,
                            "method": "UNKNOWN",
                            "refs_count": entry.refs_count,
                            "refs": [dataclasses.asdict(r) for r in entry.refs[:50]],
                        }
                    )
                continue

            if not backend_methods or method not in backend_methods:
                missing_known.append(
                    {
                        "path": path,
                        "method": method,
                        "refs_count": entry.refs_count,
                        "refs": [dataclasses.asdict(r) for r in entry.refs[:50]],
                    }
                )

        # Mismatch report when path exists but methods differ (informative)
        if backend_methods:
            frontend_methods = {m for m in by_method.keys() if m != "UNKNOWN"}
            missing_methods = sorted(frontend_methods - backend_methods)
            extra_methods = sorted(backend_methods - frontend_methods)
            # Gate: only missing methods block. Extra backend methods are informational and should not fail parity.
            if missing_methods:
                method_mismatch.append(
                    {
                        "path": path,
                        "missing_methods": missing_methods,
                        "extra_methods": extra_methods,
                    }
                )

    if show_extra:
        frontend_paths = set(frontend_map.keys())
        for path, methods in sorted(backend_map.items()):
            if path in frontend_paths:
                continue
            if is_denied_backend(path):
                continue
            extra.append({"path": path, "methods": sorted(methods)})

    # Batch selection (snapshot-driven, deterministic)
    def _route_base(p: str) -> str:
        parts = (p or "").split("/")
        if len(parts) >= 3 and parts[1] == "api":
            return "/".join(parts[:3])
        return p or ""

    pinned_norm = [normalize_path(p) for p in batch_pin if p]
    pinned_set = set(pinned_norm)

    pinned_items = [it for it in missing_known if it.get("path") in pinned_set]
    remaining = [it for it in missing_known if it.get("path") not in pinned_set]
    remaining = sorted(
        remaining,
        key=lambda it: (-int(it.get("refs_count") or 0), str(it.get("path") or ""), str(it.get("method") or "")),
    )
    selected = pinned_items + remaining[: max(0, DEFAULT_BATCH_K - len(pinned_items))]

    batch_summary: dict[str, int] = defaultdict(int)
    for it in selected:
        batch_summary[_route_base(str(it.get("path") or ""))] += 1

    ok = not missing_known and not method_mismatch and not violations
    exit_code = 0 if ok else 1
    if fail_on_extra and extra:
        exit_code = 1

    result: dict[str, Any] = {
        "ok": exit_code == 0,
        "target": target,
        "parity_check_version": PARITY_CHECK_VERSION,
        "generated_at": _utc_now_iso(),
        "git_commit": _git_commit(repo_root),
        "repo_root": str(repo_root),
        "sources_scanned": sources_scanned,
        "backend": {"count": len(backend_map), "sample": sorted(backend_map.keys())[:20]},
        "missing_known_method": missing_known,
        "missing_unknown_method": missing_unknown,
        "method_mismatch": method_mismatch,
        "unknown_methods": unknown_methods,
        "warnings": warnings,
        "violations": violations,
        "query_keys_used": {p: dict(kv) for p, kv in query_keys_used.items()},
        "batch": {
            "pin": batch_pin,
            "k": DEFAULT_BATCH_K,
            "selected": selected,
            "summary_by_route_base": dict(batch_summary),
        },
    }

    if write_snapshot:
        snap_dir = repo_root / "pronto-docs" / "parity-snapshots"
        snap_dir.mkdir(parents=True, exist_ok=True)
        yyyymmdd = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d")
        name = "EMPLOYEES" if target == "employees" else "CLIENTS"
        snap_path = snap_dir / f"{name}-{yyyymmdd}.json"
        snap_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        result["snapshot_written"] = str(snap_path)

    return result, exit_code


def main_routes_only_check(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="pronto-routes-only-check")
    ap.add_argument("target", choices=["employees", "clients", "api"])
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--repo-root", dest="repo_root")
    ns = ap.parse_args(argv)

    try:
        repo_root = detect_repo_root(__file__, ns.repo_root)
        out = routes_only_check(repo_root, ns.target)  # type: ignore[arg-type]
        if ns.json:
            print(json.dumps(out))
        else:
            print(out)
        return 0 if out.get("ok") else 1
    except Exception as e:
        err = {"ok": False, "error": str(e), "stack": ""}
        print(json.dumps(err))
        return 1


def main_parity_check(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="pronto-api-parity-check")
    ap.add_argument("target", choices=["employees", "clients"])
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--repo-root", dest="repo_root")
    ap.add_argument("--show-extra", action="store_true", default=False)
    ap.add_argument("--fail-on-extra", action="store_true", default=False)
    ap.add_argument("--write-snapshot", action="store_true", default=False)
    ap.add_argument("--batch-pin", action="append", default=[])
    ns = ap.parse_args(argv)

    try:
        repo_root = detect_repo_root(__file__, ns.repo_root)
        result, exit_code = parity_check(
            repo_root=repo_root,
            target=ns.target,  # type: ignore[arg-type]
            show_extra=bool(ns.show_extra),
            fail_on_extra=bool(ns.fail_on_extra),
            batch_pin=list(ns.batch_pin or []),
            write_snapshot=bool(ns.write_snapshot),
        )
        if ns.json:
            print(json.dumps(result))
        else:
            print(json.dumps(result, indent=2, ensure_ascii=False))
        return exit_code
    except Exception as e:
        err = {"ok": False, "error": str(e), "stack": "", "parity_check_version": PARITY_CHECK_VERSION}
        print(json.dumps(err))
        return 1


def main(argv: list[str]) -> int:
    if not argv:
        print("usage: api_parity_check.py <routes-only-check|parity-check> ...", file=sys.stderr)
        return 2
    cmd, rest = argv[0], argv[1:]
    if cmd == "routes-only-check":
        return main_routes_only_check(rest)
    if cmd == "parity-check":
        return main_parity_check(rest)
    print(f"unknown subcommand: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
