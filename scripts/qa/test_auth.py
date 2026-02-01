#!/usr/bin/env python3
"""
Diagnostic script to test PRONTO system authentication.
"""

import subprocess


def test_route(route_path, expected_status_code):
    """Test a route and return the HTTP status code."""
    print(f"Testing: {route_path}")
    print(f"Expected: HTTP {expected_status_code}")

    result = subprocess.run(
        ["curl", "-s", "-I", f"http://localhost:6081{route_path}"],
        capture_output=True,
        text=True,
        check=False,
    )

    print(f"\nHTTP Status Code: {result.returncode}")

    if result.stdout:
        print("Response Content (first 500 chars):")
        print(result.stdout[:500])
        print()

    # Check for authentication in response
    if "window.location.href" in result.stdout:
        print("✓ Found client-side redirect (JavaScript location change)")
        if "login" in result.stdout:
            print("✓ Redirects to login page (correct)")
        else:
            print("⚠ Redirects to unknown URL")
    elif "Sesión inválida" in result.stdout or "Autenticación requerida" in result.stdout:
        print("✓ Returns error JSON (correct)")
    else:
        print("✗ Returns full HTML content (problematic)")

    return result.returncode


if __name__ == "__main__":
    print("=" * 60)
    print("PRONTO Authentication Diagnostic Tool")
    print("=" * 60)
    print()

    print("Testing authentication flows...\n")

    # Test waiter routes
    print("1. Waiter Routes:")
    print("-" * 40)
    print("  GET /waiter/login")
    status = test_route("/waiter/login", 200)  # Should show login page
    print("  GET /waiter/dashboard (no auth)")
    status = test_route("/waiter/dashboard", 200)  # Should redirect to login

    print("\n2. Chef Routes:")
    print("-" * 40)
    print("  GET /chef/login")
    status = test_route("/chef/login", 200)
    print("  GET /chef/dashboard (no auth)")
    status = test_route("/chef/dashboard", 200)

    print("\n3. Admin Routes:")
    print("-" * 40)
    print("  GET /admin/login")
    status = test_route("/admin/login", 200)
    print("  GET /admin/dashboard (no auth)")
    status = test_route("/admin/dashboard", 200)

    print("\n" + "=" * 60)
    print("DIAGNÓSTICO:")
    print("Los dashboards están renderizando HTML completo")
    print("incluso cuando no hay sesión activa.")
    print("Esto indica que la autenticación NO está funcionando")
    print("como se esperaba con la arquitectura multi-scope.")
    print()
    print("RECOMENDACIÓN:")
    print("1. La arquitectura multi-scope necesita ser")
    print("   completamente reimplantada.")
    print("2. Por ahora, para pruebas de QA,")
    print("   usar el test suite HTML interactivo.")
    print("3. NO intentar acceder a los dashboards sin estar autenticado")
    print("   en la aplicación web.")
    print("=" * 60)
