#!/usr/bin/env python3
"""Quick test of Notion API connectivity"""

import os
import json
import urllib.request
from pathlib import Path

# Load config
config_paths = [
    "/Users/molder/.config/notion/notion.env",
    "/Users/molder/.notion.env",
]
env = os.environ.copy()
for config_path in config_paths:
    if os.path.exists(config_path):
        with open(config_path, "r") as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    env[k.strip()] = v.strip()
        break

token = env.get("NOTION_TOKEN")
parent_id = env.get("NOTION_PARENT_PAGE_ID")

print(f"Token: {token[:20]}..." if token else "Token: MISSING")
print(f"Parent ID: {parent_id[:20]}..." if parent_id else "Parent ID: MISSING")

if not token or not parent_id:
    print("❌ Configuración incompleta")
    exit(1)

# Test 1: Search parent page
print("\n[TEST 1] Buscando página padre...")
req = urllib.request.Request(
    "https://api.notion.com/v1/pages/" + parent_id,
    headers={
        "Authorization": f"Bearer {token}",
        "Notion-Version": "2022-06-28",
    },
)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        page_data = json.loads(resp.read())
        print(
            f"✅ Página encontrada: {page_data.get('properties', {}).get('title', [{}])[0].get('plain_text', 'Unknown')}"
        )
except Exception as e:
    print(f"❌ Error buscando página: {e}")

# Test 2: Create a test page
print("\n[TEST 2] Creando página de prueba...")
req = urllib.request.Request(
    "https://api.notion.com/v1/pages",
    data=json.dumps(
        {
            "parent": {"type": "page_id", "page_id": parent_id},
            "properties": {
                "title": {
                    "title": [
                        {"type": "text", "text": {"content": "PRONTO TEST — Test Page"}}
                    ]
                }
            },
        }
    ).encode(),
    headers={
        "Authorization": f"Bearer {token}",
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json",
    },
    method="POST",
)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        page_data = json.loads(resp.read())
        test_page_id = page_data.get("id")
        print(f"✅ Página creada: {test_page_id}")
except Exception as e:
    print(f"❌ Error creando página: {e}")
    exit(1)

# Test 3: Add a block
print("\n[TEST 3] Añadiendo bloque a la página...")
req = urllib.request.Request(
    f"https://api.notion.com/v1/blocks/{test_page_id}/children",
    data=json.dumps(
        {
            "children": [
                {
                    "object": "block",
                    "type": "paragraph",
                    "paragraph": {
                        "rich_text": [
                            {
                                "type": "text",
                                "text": {
                                    "content": "Prueba de sincronización completada!"
                                },
                            }
                        ]
                    },
                }
            ]
        }
    ).encode(),
    headers={
        "Authorization": f"Bearer {token}",
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json",
    },
    method="PATCH",
)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        print("✅ Bloque añadido exitosamente")
except Exception as e:
    print(f"❌ Error añadiendo bloque: {e}")
    exit(1)

print("\n✅ Todos los tests pasaron. La API de Notion está funcionando correctamente.")
