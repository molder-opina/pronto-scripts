#!/usr/bin/env python3
"""
Script para generar imágenes de productos con IA usando DALL-E de OpenAI.

Uso:
    python scripts/generate_product_images.py [--api-key YOUR_KEY] [--output-dir DIR]

Opciones:
    --api-key      API key de OpenAI (o usar OPENAI_API_KEY en .env)
    --output-dir   Directorio donde guardar las imágenes (default: static/assets/pronto/menu)
    --force        Regenerar todas las imágenes, incluso si ya existen
    --dry-run      Mostrar qué imágenes se generarían sin crearlas

Requisitos:
    pip install openai pillow
"""

import argparse
import os
import sys
import time
from io import BytesIO
from pathlib import Path

import requests
from openai import OpenAI
from PIL import Image

# Cargar variables de ambiente desde .env
PROJECT_ROOT = Path(__file__).parent.parent
REPO_ROOT = PROJECT_ROOT.parent
ENV_FILE = PROJECT_ROOT / ".env"


def load_env_file(env_path):
    """Cargar variables de ambiente desde un archivo .env"""
    if not env_path.exists():
        return

    with env_path.open() as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip()
                if key not in os.environ:
                    os.environ[key] = value


# Cargar archivos de configuración
load_env_file(ENV_FILE)

# Agregar pronto-libs al path
PRONTO_LIBS_SRC = REPO_ROOT / "pronto-libs/src"
if PRONTO_LIBS_SRC.exists():
    sys.path.insert(0, str(PRONTO_LIBS_SRC))

from sqlalchemy import select  # noqa: E402

from pronto_shared.config import load_config  # noqa: E402
from pronto_shared.db import get_session, init_db, init_engine  # noqa: E402
from pronto_shared.models import Base, MenuCategory, MenuItem  # noqa: E402

# Mapeo de categorías a estilos de imagen
CATEGORY_STYLES = {
    "Combos": "professional food photography, complete meal combo on white background, studio lighting, appetizing presentation",
    "Hamburguesas": "professional burger photography, juicy burger with fresh ingredients, white background, studio lighting, mouth-watering",
    "Pizzas": "professional pizza photography, artisanal pizza with melted cheese, white background, studio lighting, delicious",
    "Tacos": "professional mexican food photography, authentic tacos with fresh ingredients, white background, studio lighting, vibrant",
    "Ensaladas": "professional salad photography, fresh colorful salad, white background, studio lighting, healthy and appetizing",
    "Bebidas": "professional beverage photography, refreshing drink in glass, white background, studio lighting, condensation drops",
    "Postres": "professional dessert photography, sweet delicious dessert, white background, studio lighting, indulgent",
    "Desayunos": "professional breakfast photography, morning meal with fresh ingredients, white background, studio lighting, appetizing",
    "Botanas": "professional appetizer photography, shareable snacks, white background, studio lighting, delicious",
    "Antojitos Mexicanos": "professional mexican food photography, traditional mexican antojitos, white background, studio lighting, authentic",
    "Sopas": "professional soup photography, hot comforting soup in bowl, white background, studio lighting, steaming",
    "Especialidades": "professional gourmet food photography, signature dish, white background, studio lighting, premium presentation",
}


def generate_product_prompt(
    product_name: str, description: str, category_name: str
) -> str:
    """Genera un prompt optimizado para DALL-E basado en el producto."""
    base_style = CATEGORY_STYLES.get(
        category_name,
        "professional food photography, white background, studio lighting",
    )

    # Limpiar descripción de caracteres especiales
    clean_desc = description.replace(".", ",") if description else ""

    prompt = f"{product_name}"
    if clean_desc:
        prompt += f", {clean_desc}"
    prompt += f", {base_style}, high quality, 4k, restaurant menu style"

    return prompt


def generate_image_with_dalle(prompt: str, output_path: Path, api_key: str) -> bool:
    """Genera una imagen usando DALL-E 3 de OpenAI."""
    try:
        client = OpenAI(api_key=api_key)

        print(f"  🎨 Generando imagen con prompt: {prompt[:80]}...")

        # Generar imagen con DALL-E 3
        response = client.images.generate(
            model="dall-e-3",
            prompt=prompt,
            size="1024x1024",
            quality="standard",
            n=1,
        )

        image_url = response.data[0].url

        # Descargar la imagen
        print("  📥 Descargando imagen...")
        img_response = requests.get(image_url, timeout=30)
        img_response.raise_for_status()

        # Abrir y procesar la imagen
        img = Image.open(BytesIO(img_response.content))

        # Convertir a RGB si es necesario
        if img.mode != "RGB":
            img = img.convert("RGB")

        # Redimensionar a un tamaño más manejable (800x800)
        img.thumbnail((800, 800), Image.Resampling.LANCZOS)

        # Crear directorio si no existe
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Guardar como PNG
        img.save(output_path, "PNG", optimize=True)

        print(f"  ✅ Imagen guardada en: {output_path}")
        return True

    except ImportError as e:
        print(
            "  ❌ Error: Falta instalar dependencias. Ejecuta: pip install openai pillow requests"
        )
        print(f"     Detalle: {e}")
        return False
    except Exception as e:
        print(f"  ❌ Error generando imagen: {e}")
        return False


def generate_product_images(
    api_key: str, output_dir: Path, force: bool = False, dry_run: bool = False
):
    """Genera imágenes para todos los productos del menú."""

    print("\n🎨 GENERADOR DE IMÁGENES DE PRODUCTOS CON IA")
    print("=" * 60)

    if dry_run:
        print("⚠️  MODO DRY-RUN: No se generarán imágenes realmente\n")

    if not api_key:
        print("❌ Error: Se requiere API key de OpenAI")
        print("   Configura OPENAI_API_KEY en .env o usa --api-key")
        return

    config = load_config("generate-product-images")
    init_engine(config)
    init_db(Base.metadata)

    with get_session() as session:
        # Obtener todos los productos con sus categorías
        stmt = (
            select(MenuItem, MenuCategory)
            .join(MenuCategory, MenuItem.category_id == MenuCategory.id)
            .order_by(MenuCategory.display_order, MenuItem.id)
        )

        results = session.execute(stmt).all()

        total = len(results)
        generated = 0
        skipped = 0
        errors = 0

        print(f"📦 Encontrados {total} productos en el menú\n")

        for menu_item, category in results:
            print(
                f"\n[{generated + skipped + errors + 1}/{total}] {category.name} - {menu_item.name}"
            )

            # Determinar ruta de salida
            if menu_item.image_path:
                # Usar la ruta definida en el producto
                # Formato: /assets/pronto/menu/producto.png
                relative_path = menu_item.image_path.lstrip("/")
                output_path = REPO_ROOT / "pronto-static" / "src/static_content" / relative_path
            else:
                # Generar nombre de archivo
                filename = menu_item.name.lower().replace(" ", "_").replace("/", "_")
                filename = "".join(c for c in filename if c.isalnum() or c == "_")
                filename = f"{filename}.png"
                output_path = output_dir / filename

            # Verificar si ya existe
            if output_path.exists() and not force:
                print("  ⏭️  Ya existe, omitiendo (usa --force para regenerar)")
                skipped += 1
                continue

            if dry_run:
                prompt = generate_product_prompt(
                    menu_item.name, menu_item.description, category.name
                )
                print(f"  🔍 Se generaría: {output_path}")
                print(f"  📝 Prompt: {prompt[:100]}...")
                generated += 1
                continue

            # Generar prompt
            prompt = generate_product_prompt(
                menu_item.name, menu_item.description, category.name
            )

            # Generar imagen
            success = generate_image_with_dalle(prompt, output_path, api_key)

            if success:
                generated += 1

                # Actualizar la ruta en la base de datos si no estaba definida
                if not menu_item.image_path:
                    restaurant_slug = (
                        os.getenv("RESTAURANT_NAME", "pronto").lower().replace(" ", "-")
                    )
                    menu_item.image_path = (
                        f"/assets/{restaurant_slug}/menu/{output_path.name}"
                    )
                    session.commit()
                    print(f"  💾 Actualizada ruta en BD: {menu_item.image_path}")
            else:
                errors += 1

            # Pequeña pausa para no saturar la API
            if not dry_run and success:
                time.sleep(1)

    # Resumen
    print("\n" + "=" * 60)
    print("📊 RESUMEN")
    print("=" * 60)
    print(f"  Total de productos: {total}")
    print(f"  ✅ Imágenes generadas: {generated}")
    print(f"  ⏭️  Omitidas (ya existían): {skipped}")
    print(f"  ❌ Errores: {errors}")
    print("=" * 60 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Genera imágenes de productos con IA usando DALL-E"
    )
    parser.add_argument(
        "--api-key",
        default=os.getenv("OPENAI_API_KEY"),
        help="API key de OpenAI (default: variable OPENAI_API_KEY)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "pronto-static" / "src/static_content" / "assets" / "pronto" / "menu",
        help="Directorio de salida para las imágenes",
    )
    parser.add_argument(
        "--force", action="store_true", help="Regenerar imágenes incluso si ya existen"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Mostrar qué se haría sin generar imágenes",
    )

    args = parser.parse_args()

    generate_product_images(
        api_key=args.api_key,
        output_dir=args.output_dir,
        force=args.force,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
