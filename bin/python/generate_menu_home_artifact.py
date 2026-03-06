#!/usr/bin/env python3
"""Generate/publish static home-menu artifact from canonical menu services."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import sys
from pathlib import Path
from typing import Any


def _bootstrap_pronto_shared() -> None:
    try:
        import pronto_shared  # noqa: F401
        return
    except ImportError:
        pass

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parents[3]
    libs_src = repo_root / "pronto-libs" / "src"
    if str(libs_src) not in sys.path:
        sys.path.insert(0, str(libs_src))

    try:
        import pronto_shared  # noqa: F401
    except ImportError as exc:
        raise RuntimeError(
            f"pronto_shared no disponible; agrega {libs_src} a PYTHONPATH"
        ) from exc


def _write_artifact_file(*, output_path: Path, payload: dict[str, Any]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(payload, ensure_ascii=True, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
    )
    revision = str(payload.get("revision") or "")
    if revision:
        output_path.with_suffix(output_path.suffix + ".revision").write_text(
            f"{revision}\n",
            encoding="utf-8",
        )


def _success_payload(data: dict[str, Any]) -> dict[str, Any]:
    payload = data.get("data")
    if isinstance(payload, dict):
        return payload
    return data


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate/publish PRONTO static menu home artifact."
    )
    parser.add_argument("--placement", default="home_client")
    parser.add_argument(
        "--output",
        default=(
            "/Users/molder/projects/github-molder/pronto/pronto-static/"
            "src/static_content/assets/pronto/menu/home-published.json"
        ),
        help="Artifact output JSON file path.",
    )
    parser.add_argument(
        "--publish",
        action="store_true",
        help="Run atomic publish before exporting artifact.",
    )
    parser.add_argument(
        "--build-cmd",
        default="",
        help="Optional build command (quoted string) executed before publish promotion.",
    )
    parser.add_argument(
        "--deploy-cmd",
        default="",
        help="Optional deploy command (quoted string) executed before publish promotion.",
    )
    parser.add_argument(
        "--simulate-failure",
        choices=["build", "deploy"],
        default=None,
        help="Testing hook for publish failure simulation.",
    )
    parser.add_argument(
        "--preview",
        action="store_true",
        help="Generate from draft preview payload instead of published snapshot.",
    )
    args = parser.parse_args()

    _bootstrap_pronto_shared()

    from pronto_shared.config import load_config
    from pronto_shared.db import init_engine
    from pronto_shared.services.menu_service import (
        get_menu_home_modules_preview,
        get_published_menu_home_snapshot,
        publish_menu_home_snapshot,
    )

    config = load_config("pronto-scripts")
    init_engine(config)

    output_path = Path(args.output).expanduser().resolve()

    if args.publish:
        build_command = shlex.split(args.build_cmd) if args.build_cmd else None
        deploy_command = shlex.split(args.deploy_cmd) if args.deploy_cmd else None
        response, status = publish_menu_home_snapshot(
            placement=args.placement,
            simulate_failure=args.simulate_failure,
            artifact_output_path=str(output_path),
            build_command=build_command,
            deploy_command=deploy_command,
        )
        if int(status) >= 400:
            print(json.dumps({"status": "error", "response": response}, ensure_ascii=True))
            return 1
        print(
            json.dumps(
                {"status": "ok", "action": "published", "result": _success_payload(response)},
                ensure_ascii=True,
            )
        )
        return 0

    if args.preview:
        preview = _success_payload(get_menu_home_modules_preview(placement=args.placement))
        payload = preview.get("payload") or {}
        artifact = {
            **payload,
            "placement": args.placement,
            "revision": str(preview.get("snapshot_revision") or "draft-preview"),
            "version": int(preview.get("draft_version") or 0),
        }
        _write_artifact_file(output_path=output_path, payload=artifact)
        print(
            json.dumps(
                {
                    "status": "ok",
                    "action": "preview_generated",
                    "output": str(output_path),
                    "revision": artifact["revision"],
                },
                ensure_ascii=True,
            )
        )
        return 0

    published = _success_payload(get_published_menu_home_snapshot(placement=args.placement))
    payload = published.get("payload") or {}
    artifact = {
        **payload,
        "placement": args.placement,
        "revision": str(published.get("revision") or "baseline-v1"),
        "version": int(published.get("version") or 1),
    }
    _write_artifact_file(output_path=output_path, payload=artifact)
    print(
        json.dumps(
            {
                "status": "ok",
                "action": "artifact_generated",
                "output": str(output_path),
                "revision": artifact["revision"],
            },
            ensure_ascii=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
