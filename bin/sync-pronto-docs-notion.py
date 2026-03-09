#!/usr/bin/env python3
"""Sync PRONTO markdown docs (pronto-docs) into Notion.

Creates/uses one page per 'doc area' under NOTION_PARENT_PAGE_ID.
By default we group by top-level filename or folder.

Env (from /Users/molder/.config/notion/notion.env or /Users/molder/.notion.env):
- NOTION_TOKEN (required)
- NOTION_PARENT_PAGE_ID (required)

Usage:
  python3 sync-pronto-docs-notion.py --docs-root "/Users/molder/projects/github-molder/pronto/pronto-docs"

Notes:
- Read-only on repo; only pushes to Notion.
- Keeps API calls reasonable: one page per file (or per group) and appends/replaces content.
"""

import argparse
import json
import os
import re
import time
import urllib.request
import urllib.error
from pathlib import Path

NOTION_VERSION = "2022-06-28"
MAX_CHARS = 18000
SLEEP_BETWEEN_CALLS = 0.02  # Reducido drásticamente
BATCH_SIZE = 200


def load_env(path: str) -> dict:
    env = {}
    if not os.path.exists(path):
        return env
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    return env


def notion_req(method: str, url: str, token: str, payload=None):
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Notion-Version": NOTION_VERSION,
        "Content-Type": "application/json",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=45) as resp:
        body = resp.read().decode("utf-8")
        return json.loads(body) if body else {}


def rich_text(text: str):
    return [{"type": "text", "text": {"content": text}}]


def md_to_blocks(md: str):
    blocks = []
    parts = md.split("\n\n")
    for p in parts:
        p = p.strip("\n")
        if not p:
            continue
        if p.startswith("```"):
            m = re.match(r"```(\w+)?\n([\s\S]*)\n```", p)
            if m:
                lang = (m.group(1) or "").lower() or "plain text"
                code = m.group(2)
                blocks.append(
                    {
                        "object": "block",
                        "type": "code",
                        "code": {
                            "rich_text": rich_text(code[:MAX_CHARS]),
                            "language": "plain text"
                            if lang
                            not in [
                                "plain text",
                                "text",
                                "json",
                                "bash",
                                "shell",
                                "markdown",
                                "yaml",
                                "toml",
                            ]
                            else lang,
                        },
                    }
                )
                continue
        if p.startswith("### "):
            blocks.append(
                {
                    "object": "block",
                    "type": "heading_3",
                    "heading_3": {"rich_text": rich_text(p[4:][:200])},
                }
            )
        elif p.startswith("## "):
            blocks.append(
                {
                    "object": "block",
                    "type": "heading_2",
                    "heading_2": {"rich_text": rich_text(p[3:][:200])},
                }
            )
        elif p.startswith("# "):
            blocks.append(
                {
                    "object": "block",
                    "type": "heading_1",
                    "heading_1": {"rich_text": rich_text(p[2:][:200])},
                }
            )
        else:
            blocks.append(
                {
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": {"rich_text": rich_text(p[:MAX_CHARS])},
                }
            )
    return blocks


def search_page_by_title(parent_id: str, token: str, title: str):
    # Skip search to improve speed - always try to create
    # If page exists, Notion will return an error and we can handle it
    return None


def create_page(parent_id: str, token: str, title: str):
    payload = {
        "parent": {"type": "page_id", "page_id": parent_id},
        "properties": {"title": {"title": rich_text(title)}},
    }
    try:
        res = notion_req("POST", "https://api.notion.com/v1/pages", token, payload)
        return res.get("id")
    except urllib.error.HTTPError as e:
        # If page already exists (400 error), search for it
        if e.code == 400:
            print(f"  → Página ya existe, buscando ID...")
            res = notion_req(
                "POST",
                "https://api.notion.com/v1/search",
                token,
                {
                    "query": title,
                    "filter": {"property": "object", "value": "page"},
                    "page_size": 10,
                },
            )
            for r in res.get("results", []):
                p = r.get("parent", {})
                if p.get("type") == "page_id" and p.get("page_id") == parent_id:
                    props = r.get("properties", {})
                    t = props.get("title") or props.get("Name")
                    if t and t.get("type") == "title":
                        txt = "".join(
                            [x.get("plain_text", "") for x in t.get("title", [])]
                        )
                        if txt.strip() == title:
                            return r.get("id")
        raise


def delete_all_children(block_id: str, token: str):
    # Notion doesn't support bulk delete; we "archive" blocks by listing children and deleting each.
    # To keep API usage low, we don't do full delete. Instead we append a new section with timestamp.
    return


def append_blocks(block_id: str, token: str, blocks):
    payload = {"children": blocks}
    try:
        notion_req(
            "PATCH",
            f"https://api.notion.com/v1/blocks/{block_id}/children",
            token,
            payload,
        )
    except urllib.error.HTTPError as e:
        print(f"[ERROR] Fallo al añadir bloques a {block_id}: {e}")
        raise


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--docs-root", required=True)
    ap.add_argument("--max-files", type=int, default=200)
    args = ap.parse_args()

    env = os.environ.copy()

    # Try multiple config locations in order
    config_paths = [
        "/Users/molder/.config/notion/notion.env",
        "/Users/molder/.notion.env",
        os.path.join(os.path.dirname(__file__), "notion.env"),
    ]

    for config_path in config_paths:
        if os.path.exists(config_path):
            env.update(load_env(config_path))
            break

    token = env.get("NOTION_TOKEN")
    parent_id = env.get("NOTION_PARENT_PAGE_ID")
    if not token:
        raise SystemExit("Missing NOTION_TOKEN")
    if not parent_id or parent_id.strip().startswith("("):
        raise SystemExit("Missing NOTION_PARENT_PAGE_ID in notion.env")

    docs_root = Path(args.docs_root)
    md_files = sorted([p for p in docs_root.rglob("*.md") if p.is_file()])
    md_files = md_files[: args.max_files]

    # One page per file under parent, named "PRONTO Docs — <relative path>"
    total_files = len(md_files)
    for idx, p in enumerate(md_files, 1):
        rel = str(p.relative_to(docs_root))
        title = f"PRONTO Docs — {rel}"

        print(f"[{idx}/{total_files}] Procesando: {rel}...")

        try:
            # Try to create the page directly (skips slow search)
            page_id = create_page(parent_id, token, title)
            print(f"  → Creada nueva página: {page_id[:10]}...")
            time.sleep(SLEEP_BETWEEN_CALLS)

            content = p.read_text(encoding="utf-8", errors="ignore")
            header = f"# {rel}\n\n(Actualizado automáticamente)\n\n"
            blocks = md_to_blocks(header + content)

            from datetime import datetime

            stamp = datetime.now().strftime("%Y-%m-%d %H:%M")
            stamped_blocks = md_to_blocks(f"## Actualización {stamp}\n") + blocks

            for i in range(0, len(stamped_blocks), BATCH_SIZE):
                append_blocks(page_id, token, stamped_blocks[i : i + BATCH_SIZE])
                time.sleep(SLEEP_BETWEEN_CALLS)

            print(f"✅ [{idx}/{total_files}] Sincronizado: {rel}")
        except Exception as e:
            print(f"❌ [{idx}/{total_files}] Error al sincronizar {rel}: {e}")
            time.sleep(1)  # Esperar antes de intentar el siguiente

    print(f"\n✅ Sincronización completada: {total_files} archivos procesados")


if __name__ == "__main__":
    main()
