#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


FAIL_LEVELS = {"p0": 3, "p1": 2, "p2": 1}
SEVERITIES = ("p0", "p1", "p2")


@dataclass
class Auditor:
    id: str
    prompt: Path
    severity: str
    group: str
    tags: list[str]
    fast: bool


def detect_repo_root(cli_repo_root: str | None) -> Path:
    if cli_repo_root:
        root = Path(cli_repo_root).resolve()
    else:
        root = Path(__file__).resolve().parents[2]

    expected = [root / "AGENTS.md", root / "pronto-prompts", root / "pronto-scripts"]
    if sum(1 for p in expected if p.exists()) < 2:
        raise RuntimeError(f"repo_root invalido: {root}")
    return root


def load_registry(
    repo_root: Path, registry_rel: str
) -> tuple[Path, list[Auditor], dict[str, Any]]:
    registry_path = (repo_root / registry_rel).resolve()
    if not registry_path.exists():
        raise RuntimeError(f"registry no existe: {registry_path}")

    data = load_simple_yaml_registry(registry_path)

    raw = data.get("auditors")
    if not isinstance(raw, list) or not raw:
        raise RuntimeError("registry.yml sin lista de auditores")

    auditors: list[Auditor] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        aid = str(item.get("id") or "").strip()
        prompt_rel = str(item.get("prompt") or "").strip()
        if not aid or not prompt_rel:
            continue
        prompt = (repo_root / "pronto-prompts" / prompt_rel).resolve()
        auditors.append(
            Auditor(
                id=aid,
                prompt=prompt,
                severity=str(item.get("severity") or "advisory"),
                group=str(item.get("group") or "general"),
                tags=[str(t) for t in (item.get("tags") or []) if isinstance(t, str)],
                fast=bool(item.get("fast", False)),
            )
        )

    if not auditors:
        raise RuntimeError("registry.yml no contiene auditores validos")
    return registry_path, auditors, data


def _parse_scalar(raw: str) -> Any:
    text = raw.strip()
    if text.lower() == "true":
        return True
    if text.lower() == "false":
        return False
    if re.fullmatch(r"\d+", text):
        return int(text)
    if text.startswith("[") and text.endswith("]"):
        body = text[1:-1].strip()
        if not body:
            return []
        parts = [p.strip().strip("\"'") for p in body.split(",")]
        return [p for p in parts if p]
    return text.strip("\"'")


def load_simple_yaml_registry(path: Path) -> dict[str, Any]:
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    out: dict[str, Any] = {}
    current_top: str | None = None
    current_item: dict[str, Any] | None = None

    for raw in lines:
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue

        if re.match(r"^[A-Za-z0-9_.-]+:\s*$", line):
            key = line.split(":", 1)[0].strip()
            out[key] = []
            current_top = key
            current_item = None
            continue

        m_top_scalar = re.match(r"^([A-Za-z0-9_.-]+):\s*(.+)$", line)
        if m_top_scalar and not line.startswith(" "):
            out[m_top_scalar.group(1)] = _parse_scalar(m_top_scalar.group(2))
            current_top = None
            current_item = None
            continue

        if current_top and isinstance(out.get(current_top), list):
            m_item = re.match(r"^\s*-\s*(.*)$", line)
            if m_item:
                current_item = {}
                out[current_top].append(current_item)
                rest = m_item.group(1).strip()
                if rest and ":" in rest:
                    k, v = rest.split(":", 1)
                    current_item[k.strip()] = _parse_scalar(v)
                continue

            if current_item is not None:
                m_kv = re.match(r"^\s+([A-Za-z0-9_.-]+):\s*(.*)$", line)
                if m_kv:
                    current_item[m_kv.group(1).strip()] = _parse_scalar(m_kv.group(2))

    return out


def select_auditors(
    auditors: list[Auditor], agent: str | None, group: str | None, fast: bool
) -> list[Auditor]:
    selected = auditors
    if agent:
        selected = [a for a in selected if a.id == agent]
    if group:
        selected = [a for a in selected if a.group == group]
    if fast:
        selected = [a for a in selected if a.fast]
    return selected


def ensure_opencode() -> str:
    path = shutil.which("opencode")
    if not path:
        raise RuntimeError("opencode no disponible en PATH")
    return path


def extract_opencode_text(raw: str) -> str:
    """Extract assistant text from `opencode run --format json` output."""
    chunks: list[str] = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        part = event.get("part")
        if not isinstance(part, dict):
            continue
        if part.get("type") != "text":
            continue
        text = part.get("text")
        if isinstance(text, str) and text.strip():
            chunks.append(text.strip())
    return "\n\n".join(chunks).strip()


def parse_section_count(text: str, label: str) -> int:
    # Normalize lightweight markdown emphasis so headings like
    # "2. **Hallazgos P0**" are detected consistently.
    text = text.replace("**", "")

    heading = re.compile(
        rf"^\s*(?:\d+\.\s*)?Hallazgos\s+{label}\s*$", re.IGNORECASE | re.MULTILINE
    )
    match = heading.search(text)
    if not match:
        return 0

    tail = text[match.end() :]
    stop = re.search(
        r"^\s*(?:\d+\.\s*)?(Hallazgos\s+P[0-2]|Evidencia|Canon esperado|Divergencia detectada|Correccion sugerida|Tests obligatorios|Sugerencias para AGENTS\.md|No verificado)\s*$",
        tail,
        flags=re.IGNORECASE | re.MULTILINE,
    )
    section = tail[: stop.start()] if stop else tail

    lines = [ln.strip() for ln in section.splitlines() if ln.strip()]
    if not lines:
        return 0

    neutral = ("sin hallazgos", "ninguno", "no aplica", "none")
    joined = " ".join(lines).lower()
    if any(token in joined for token in neutral):
        return 0

    items = [ln for ln in lines if re.match(r"^([-*]|\d+[.)])\s+", ln)]
    if items:
        return len(items)
    return 1


def extract_counts(text: str) -> dict[str, int]:
    return {
        "p0": parse_section_count(text, "P0"),
        "p1": parse_section_count(text, "P1"),
        "p2": parse_section_count(text, "P2"),
    }


def evaluate_verdict(total: dict[str, int], fail_on: str, had_errors: bool) -> str:
    if had_errors:
        return "FAIL-BLOCKING"
    threshold = FAIL_LEVELS[fail_on]
    score = 0
    if total["p0"] > 0:
        score = max(score, FAIL_LEVELS["p0"])
    if total["p1"] > 0:
        score = max(score, FAIL_LEVELS["p1"])
    if total["p2"] > 0:
        score = max(score, FAIL_LEVELS["p2"])
    if score >= threshold:
        return "FAIL-BLOCKING" if total["p0"] > 0 else "FAIL"
    return "PASS"


def write_summary_markdown(path: Path, payload: dict[str, Any]) -> None:
    lines: list[str] = []
    lines.append("# PRONTO AI Audit Report")
    lines.append("")
    lines.append(f"- Timestamp: {payload['generated_at']}")
    lines.append(f"- Repo Root: `{payload['repo_root']}`")
    lines.append(f"- Registry: `{payload['registry']}`")
    lines.append(f"- Fail On: `{payload['fail_on']}`")
    lines.append(f"- Verdict: **{payload['verdict']}**")
    lines.append("")
    lines.append("## Totales")
    lines.append("")
    lines.append(f"- P0: {payload['total']['p0']}")
    lines.append(f"- P1: {payload['total']['p1']}")
    lines.append(f"- P2: {payload['total']['p2']}")
    lines.append("")
    lines.append("## Auditores")
    lines.append("")
    for item in payload["auditors"]:
        status = "error" if item.get("error") else "ok"
        lines.append(
            f"- `{item['id']}` [{status}] p0={item['counts']['p0']} p1={item['counts']['p1']} p2={item['counts']['p2']} output=`{item['output']}`"
        )
        if item.get("error"):
            lines.append(f"  - error: {item['error']}")
    lines.append("")
    lines.append("## Artefactos")
    lines.append("")
    lines.append(f"- JSON: `{payload['report_json']}`")
    lines.append(f"- Summary: `{payload['summary_md']}`")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run_audit(args: argparse.Namespace) -> int:
    repo_root = detect_repo_root(args.repo_root)
    registry_path, auditors, _ = load_registry(repo_root, args.registry)
    selected = select_auditors(auditors, args.agent, args.group, args.fast)
    if not selected:
        raise RuntimeError("No hay auditores seleccionados con los filtros dados")

    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d_%H%M%S")
    out_dir = (
        Path(args.out_dir).resolve()
        if args.out_dir
        else (repo_root / "pronto-docs" / "audits" / "ai" / timestamp)
    )
    auditors_dir = out_dir / "auditors"
    auditors_dir.mkdir(parents=True, exist_ok=True)

    opencode = ensure_opencode()
    results: list[dict[str, Any]] = []
    had_errors = False

    for auditor in selected:
        if not auditor.prompt.exists():
            results.append(
                {
                    "id": auditor.id,
                    "group": auditor.group,
                    "severity": auditor.severity,
                    "prompt": str(auditor.prompt),
                    "output": "",
                    "counts": {"p0": 0, "p1": 0, "p2": 0},
                    "error": f"prompt no existe: {auditor.prompt}",
                }
            )
            had_errors = True
            continue

        output_file = auditors_dir / f"{auditor.id}.md"
        message = (
            args.message
            or "Ejecuta la auditoria con evidencia verificable y usa el formato obligatorio de salida definido en el prompt."
        )
        cmd = [
            opencode,
            "run",
            "--dir",
            str(repo_root),
            "--file",
            str(auditor.prompt),
            "--format",
            "json",
            message,
        ]
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
                timeout=int(args.agent_timeout_seconds),
            )
        except subprocess.TimeoutExpired:
            had_errors = True
            results.append(
                {
                    "id": auditor.id,
                    "group": auditor.group,
                    "severity": auditor.severity,
                    "prompt": str(auditor.prompt),
                    "output": str(output_file),
                    "counts": {"p0": 0, "p1": 0, "p2": 0},
                    "error": f"timeout after {int(args.agent_timeout_seconds)}s",
                }
            )
            continue

        if proc.returncode != 0:
            had_errors = True
            err = (proc.stderr or proc.stdout or "error desconocido").strip()
            results.append(
                {
                    "id": auditor.id,
                    "group": auditor.group,
                    "severity": auditor.severity,
                    "prompt": str(auditor.prompt),
                    "output": str(output_file),
                    "counts": {"p0": 0, "p1": 0, "p2": 0},
                    "error": err,
                }
            )
            continue

        text = extract_opencode_text(proc.stdout or "")
        if not text:
            text = (proc.stdout or "").strip()
        if not text:
            text = (proc.stderr or "").strip()
        if not text:
            text = "No output generated by opencode run."

        output_file.write_text(text + "\n", encoding="utf-8")

        counts = extract_counts(text)
        results.append(
            {
                "id": auditor.id,
                "group": auditor.group,
                "severity": auditor.severity,
                "prompt": str(auditor.prompt),
                "output": str(output_file),
                "counts": counts,
                "error": "",
            }
        )

    total = {sev: sum(int(r["counts"][sev]) for r in results) for sev in SEVERITIES}
    verdict = evaluate_verdict(total, args.fail_on, had_errors)

    report_json = out_dir / "report.json"
    summary_md = out_dir / "summary.md"
    payload: dict[str, Any] = {
        "generated_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "repo_root": str(repo_root),
        "registry": str(registry_path),
        "fail_on": args.fail_on,
        "filters": {
            "agent": args.agent or "",
            "group": args.group or "",
            "fast": bool(args.fast),
        },
        "total": total,
        "verdict": verdict,
        "auditors": results,
        "report_json": str(report_json),
        "summary_md": str(summary_md),
    }

    report_json.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    write_summary_markdown(summary_md, payload)

    if args.format == "json":
        print(json.dumps(payload, ensure_ascii=False))
    else:
        print(summary_md)

    return 0 if verdict == "PASS" else 1


def report_only(args: argparse.Namespace) -> int:
    in_dir = Path(args.in_dir).resolve()
    auditors_dir = in_dir / "auditors"
    if not auditors_dir.exists():
        raise RuntimeError(f"directorio no valido: {auditors_dir}")

    results: list[dict[str, Any]] = []
    had_errors = False
    for output_file in sorted(auditors_dir.glob("*.md")):
        text = output_file.read_text(encoding="utf-8", errors="ignore")
        counts = extract_counts(text)
        results.append(
            {
                "id": output_file.stem,
                "group": "",
                "severity": "",
                "prompt": "",
                "output": str(output_file),
                "counts": counts,
                "error": "",
            }
        )

    if not results:
        had_errors = True

    total = {sev: sum(int(r["counts"][sev]) for r in results) for sev in SEVERITIES}
    verdict = evaluate_verdict(total, args.fail_on, had_errors)

    report_json = in_dir / "report.json"
    summary_md = in_dir / "summary.md"
    payload: dict[str, Any] = {
        "generated_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "repo_root": "",
        "registry": "",
        "fail_on": args.fail_on,
        "filters": {"agent": "", "group": "", "fast": False},
        "total": total,
        "verdict": verdict,
        "auditors": results,
        "report_json": str(report_json),
        "summary_md": str(summary_md),
    }

    report_json.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    write_summary_markdown(summary_md, payload)

    if args.format == "json":
        print(json.dumps(payload, ensure_ascii=False))
    else:
        print(summary_md)
    return 0 if verdict == "PASS" else 1


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(prog="ai_audit_runner.py")
    sub = parser.add_subparsers(dest="command", required=True)

    run_cmd = sub.add_parser("run")
    run_cmd.add_argument("--repo-root", dest="repo_root")
    run_cmd.add_argument("--registry", default="pronto-prompts/registry.yml")
    run_cmd.add_argument("--agent", dest="agent")
    run_cmd.add_argument("--group", dest="group")
    run_cmd.add_argument("--fast", action="store_true")
    run_cmd.add_argument("--format", choices=["markdown", "json"], default="markdown")
    run_cmd.add_argument("--fail-on", choices=["p0", "p1", "p2"], default="p0")
    run_cmd.add_argument("--out-dir", dest="out_dir")
    run_cmd.add_argument("--message", dest="message")
    run_cmd.add_argument(
        "--agent-timeout-seconds", dest="agent_timeout_seconds", type=int, default=240
    )

    report_cmd = sub.add_parser("report")
    report_cmd.add_argument("--in-dir", required=True)
    report_cmd.add_argument(
        "--format", choices=["markdown", "json"], default="markdown"
    )
    report_cmd.add_argument("--fail-on", choices=["p0", "p1", "p2"], default="p0")

    ns = parser.parse_args(argv)
    try:
        if ns.command == "run":
            return run_audit(ns)
        if ns.command == "report":
            return report_only(ns)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
