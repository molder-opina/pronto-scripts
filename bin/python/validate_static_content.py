#!/usr/bin/env python3
import os
import platform
import re
import sys
from pathlib import Path

# Configuration
PROJECT_ROOT = Path(__file__).parent.parent.parent.resolve()
BUILD_DIR = PROJECT_ROOT / "build"
STATIC_CONTENT_DIR = BUILD_DIR / "static_content"
CONFIG_FILE = PROJECT_ROOT / "config" / "general.env"

# Apps to scan for usage
APPS = {
    "employees_app": BUILD_DIR / "employees_app" / "templates",
    "clients_app": BUILD_DIR / "clients_app" / "templates",
}


def check_env_config():
    """Checks the PRONTO_STATIC_CONTAINER_HOST in config/general.env"""
    print(f"\nScanning configuration at {CONFIG_FILE}...")
    if not CONFIG_FILE.exists():
        print("❌ Error: config/general.env not found.")
        return None

    url = None
    try:
        content = CONFIG_FILE.read_text()
        for line in content.splitlines():
            if line.startswith("PRONTO_STATIC_CONTAINER_HOST="):
                url = line.split("=", 1)[1].strip()
                break
    except Exception as e:
        print(f"❌ Error reading config: {e}")
        return None

    if url:
        print(f"✅ Found PRONTO_STATIC_CONTAINER_HOST: {url}")

        os_type = get_os_type()
        if os_type == "darwin":  # macOS
            if "localhost" in url or "127.0.0.1" in url:
                print("✅ Configuration looks correct for macOS (local development).")
            else:
                print(
                    "⚠️ Warning: On macOS, PRONTO_STATIC_CONTAINER_HOST usually points to localhost."
                )
        elif os_type == "linux":
            if "localhost" in url or "127.0.0.1" in url:
                print(
                    "⚠️ Warning: On Linux (production), PRONTO_STATIC_CONTAINER_HOST should usually point to the external hostname/IP, not localhost, unless using a reverse proxy on the host."
                )
            else:
                print("✅ Configuration looks appropriate for Linux (production).")
    else:
        print("❌ Error: PRONTO_STATIC_CONTAINER_HOST not found in config/general.env")

    return url


# Regex patterns
# Pattern 1: Jinja usage {{ static_host_url }}/path/to/asset
# Captures: /path/to/asset (or path/to/asset)
JINJA_PATTERN = re.compile(r"\{\{\s*static_host_url\s*\}\}/?([^\'\"\s\}]+)")

# Pattern 2: JS usage window.APP_CONFIG.static_host_url + '/path/to/asset'
# This is heuristical and might need adjustment based on exact code style
JS_PATTERN = re.compile(r'static_host_url\s*[+,]\s*[\'"]([^\'"]+)[\'"]')


def get_os_type():
    return platform.system().lower()


def find_expected_assets():
    """Scans template files to find references to static assets."""
    expected_assets = set()

    for app_name, template_dir in APPS.items():
        if not template_dir.exists():
            print(f"Warning: Template directory for {app_name} not found at {template_dir}")
            continue

        print(f"Scanning {app_name} templates...")
        for template_file in template_dir.rglob("*.html"):
            try:
                content = template_file.read_text(encoding="utf-8")

                # Check Jinja usage
                matches = JINJA_PATTERN.findall(content)
                for path in matches:
                    # Clean up path
                    # Remove potential trailing quotes or brackets if regex overshot
                    path = path.split('"')[0].split("'")[0]
                    clean_path = path.lstrip("/")

                    # Ignore variables (e.g. {{ static_host_url }}/{{ item.image }})
                    if "{{" in clean_path or "}}" in clean_path:
                        continue

                    expected_assets.add(clean_path)

                # Check JS usage
                js_matches = JS_PATTERN.findall(content)
                for path in js_matches:
                    clean_path = path.lstrip("/")
                    expected_assets.add(clean_path)

            except Exception as e:
                print(f"Error reading {template_file}: {e}")

    return expected_assets


def get_available_assets():
    """Scans the static_content directory to find actual files."""
    available_assets = set()
    if not STATIC_CONTENT_DIR.exists():
        print(f"Error: Static content directory not found at {STATIC_CONTENT_DIR}")
        return available_assets

    print(f"Scanning available assets in {STATIC_CONTENT_DIR}...")
    for file_path in STATIC_CONTENT_DIR.rglob("*"):
        if file_path.is_file():
            # Get path relative to static_content dir
            try:
                rel_path = file_path.relative_to(STATIC_CONTENT_DIR)
                available_assets.add(str(rel_path))
            except ValueError:
                continue

    return available_assets


def main():
    print(f"=== Static Content Validation ({get_os_type()}) ===")
    print(f"Project Root: {PROJECT_ROOT}")

    check_env_config()

    expected = find_expected_assets()
    available = get_available_assets()

    print("\n" + "=" * 50)
    print("VALIDATION CHECKLIST")
    print("=" * 50)
    print(f"{'STATUS':<10} | {'ASSET PATH':<60}")
    print("-" * 75)

    missing_count = 0

    # Sort for better readability
    sorted_expected = sorted(list(expected))

    for asset in sorted_expected:
        # Strip query parameters (e.g. ?v=1.0) for file check
        clean_asset_path = asset.split("?")[0]

        status = "✅ OK"
        if clean_asset_path in available:
            status_color = "\033[92m✅ OK\033[0m"  # Green
        else:
            status_color = "\033[91m❌ MISSING\033[0m"  # Red
            missing_count += 1
            status = "❌ MISSING"

        # If not using ANSI supported terminal, strip colors or use simple marks.
        # For this output, we'll keep it simple text if colors might be issues,
        # but generic standard usually handles it.
        print(f"{status:<10} | {asset:<60}")

    print("-" * 75)
    print("\n=== Summary ===")
    print(f"Total Unique Assets Referenced: {len(expected)}")
    print(f"Total Assets Found in Container: {len(available)}")
    print(f"Missing Assets: {missing_count}")

    if missing_count > 0:
        print("\nFAILURE: Some static assets are missing from the container build directory.")
        sys.exit(1)
    else:
        print("\nSUCCESS: All referenced static assets are present.")
        sys.exit(0)


if __name__ == "__main__":
    main()
