#!/usr/bin/env python3
"""
Generate grayscale avatar placeholders using the free Pollinations API.

Usage:
    python scripts/generate_profile_avatars.py [--count 10] [--provider pollinations]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT / "build"))

from shared.services.ai_image_service import AIImageService  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description="Genera avatares en blanco y negro para perfiles")
    parser.add_argument("--count", type=int, default=10, help="Número de perfiles a generar (1-20)")
    parser.add_argument(
        "--provider",
        choices=[AIImageService.FREE_PROVIDER, AIImageService.OPENAI_PROVIDER],
        default=AIImageService.FREE_PROVIDER,
        help="Proveedor de IA a utilizar",
    )
    args = parser.parse_args()

    service = AIImageService()
    count = max(1, min(20, args.count))
    print(f"🎨 Generando {count} perfiles usando el proveedor '{args.provider}'...")
    images = service.generate_profile_set(count=count, provider=args.provider)

    if not images:
        print("❌ No se generó ninguna imagen. Revisa los logs para más detalles.")
        sys.exit(1)

    print(f"✅ Listo. Se generaron {len(images)} imágenes en la carpeta 'profiles'.")
    for image in images:
        print(f"   • {image['url']} ({image['size']} bytes)")


if __name__ == "__main__":
    main()
