#!/usr/bin/env python3
"""
Pronto API Test Suite - Unificado con soporte para múltiples modos.

Usage:
    python run_api_tests.py [OPTIONS]

Options:
    --simple, -s           Modo simple (sin dependencias async)
    --full, -f             Modo completo (con Rich y aiohttp) [default]
    --auth-mode            Modo autenticado: login, obtiene token, ejecuta tests de empleado
    --check                Solo verificar que la API esté disponible
    --client               Probar solo APIs de cliente
    --employee             Probar solo APIs de empleado (requiere auth)
    --health               Probar solo health endpoints
    --output FILE          Guardar resultados en archivo JSON
    --quiet, -q            Modo silencioso (menos output)
    --verbose, -v          Modo verboso (más detalles)
    --help, -h             Mostrar esta ayuda

Examples:
    python run_api_tests.py                      # Tests completos
    python run_api_tests.py --simple             # Tests simples
    python run_api_tests.py --auth-mode          # Login + tests de empleado
    python run_api_tests.py --check              # Verificar API
    python run_api_tests.py --client             # Solo APIs cliente
    python run_api_tests.py --employee           # Solo APIs empleado
    python run_api_tests.py -o results.json      # Guardar resultados

Environment Variables:
    API_BASE_URL      URL base del API (default: http://localhost:6082)
    ADMIN_EMAIL       Email de admin para autenticación
    ADMIN_PASSWORD    Password de admin para autenticación
"""

import argparse
import asyncio
import json
import os
import sys
import time
from datetime import datetime
from typing import Any
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError

try:
    import aiohttp

    HAS_AIOHTTP = True
except ImportError:
    HAS_AIOHTTP = False


BASE_URL = os.getenv("API_BASE_URL", "http://localhost:6082")
ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "admin@cafeteria.test")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "ChangeMe!123")


class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


class AuthModeTester:
    """Tester que primero se autentica y luego prueba APIs."""

    def __init__(self, quiet: bool = False):
        self.quiet = quiet
        self.token = None
        self.results = []

    def log(self, msg: str, color: str = ""):
        if not self.quiet:
            print(f"{color}{msg}{Colors.ENDC}")

    def make_request(
        self,
        method: str,
        endpoint: str,
        data: dict | None = None,
        token: str | None = None,
    ) -> tuple:
        url = f"{BASE_URL}{endpoint}"
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"

        json_data = json.dumps(data).encode() if data else None
        req = Request(url, data=json_data, headers=headers, method=method)

        start_time = time.time()
        try:
            with urlopen(req, timeout=30) as response:
                duration = time.time() - start_time
                try:
                    response_data = json.loads(response.read().decode())
                except Exception:
                    response_data = {"raw": response.read().decode()}
                return response.status, response_data, duration
        except HTTPError as e:
            duration = time.time() - start_time
            try:
                error_data = json.loads(e.read().decode())
            except Exception:
                error_data = {"error": str(e)}
            return e.code, error_data, duration
        except URLError as e:
            duration = time.time() - start_time
            return 0, {"error": str(e)}, duration

    def run_test(
        self,
        name: str,
        method: str,
        endpoint: str,
        json: dict | None = None,
        token: str | None = None,
    ) -> dict:
        status, data, duration = self.make_request(method, endpoint, json, token)
        success = 200 <= status < 300
        emoji = "✓" if success else "✗"
        color = Colors.OKGREEN if success else Colors.FAIL

        self.log(
            f"{color}{emoji}{Colors.ENDC} {name:<45} [{status}] {duration * 1000:.1f}ms"
        )

        result = {
            "name": name,
            "endpoint": endpoint,
            "method": method,
            "status": status,
            "success": success,
            "duration": duration,
            "response": data if not success else None,
        }
        self.results.append(result)
        return result

    def authenticate(self) -> bool:
        """Autenticarse y obtener token."""
        self.log(f"\n{Colors.HEADER}=== AUTENTICACIÓN ==={Colors.ENDC}")

        status, data, duration = self.make_request(
            "POST",
            "/api/employee/auth/login",
            data={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
        )

        if status == 200:
            self.token = data.get("access_token") if isinstance(data, dict) else None
            if self.token:
                self.log(f"{Colors.OKGREEN}✓ Login exitoso{Colors.ENDC}")
                self.log(f"  Token: {self.token[:20]}...")
                return True

        self.log(f"{Colors.FAIL}✗ Login fallido: {data}{Colors.ENDC}")
        return False

    def test_authenticated_endpoints(self):
        """Probar endpoints que requieren autenticación."""
        if not self.token:
            self.log(f"{Colors.FAIL}No hay token disponible{Colors.ENDC}")
            return

        self.log(
            f"\n{Colors.HEADER}=== APIs DE EMPLEADO (AUTENTICADO) ==={Colors.ENDC}"
        )

        self.run_test(
            "Verify Token", "GET", "/api/employee/auth/verify", token=self.token
        )
        self.run_test("Get Me", "GET", "/api/employee/auth/me", token=self.token)
        self.run_test(
            "Get Permissions", "GET", "/api/employee/auth/permissions", token=self.token
        )
        self.run_test(
            "Get Employees", "GET", "/api/employee/employees", token=self.token
        )
        self.run_test(
            "Get Employee by ID", "GET", "/api/employee/employees/1", token=self.token
        )
        self.run_test("Get Menu Items", "GET", "/api/employee/menu", token=self.token)
        self.run_test(
            "Get Menu Categories",
            "GET",
            "/api/employee/menu/categories",
            token=self.token,
        )
        self.run_test("Get Orders", "GET", "/api/employee/orders", token=self.token)
        self.run_test(
            "Get Order by ID", "GET", "/api/employee/orders/1", token=self.token
        )
        self.run_test("Get Tables", "GET", "/api/employee/tables", token=self.token)
        self.run_test(
            "Get Table by ID", "GET", "/api/employee/tables/1", token=self.token
        )
        self.run_test(
            "Get Sessions", "GET", "/api/employee/sessions/closed", token=self.token
        )
        self.run_test(
            "Get Customers", "GET", "/api/employee/customers/search", token=self.token
        )
        self.run_test(
            "Get Waiter Calls", "GET", "/api/employee/waiter-calls", token=self.token
        )
        self.run_test(
            "Get Promotions", "GET", "/api/employee/promotions", token=self.token
        )
        self.run_test(
            "Get Discount Codes",
            "GET",
            "/api/employee/discount-codes",
            token=self.token,
        )
        self.run_test(
            "Get Sales Report", "GET", "/api/employee/reports/sales", token=self.token
        )
        self.run_test(
            "Get Daily Summary",
            "GET",
            "/api/employee/reports/top-products",
            token=self.token,
        )
        self.run_test(
            "Get Dashboard Stats",
            "GET",
            "/api/employee/analytics/kpis",
            token=self.token,
        )
        self.run_test(
            "Get Revenue Stats",
            "GET",
            "/api/employee/analytics/revenue",
            token=self.token,
        )
        self.run_test(
            "Get Order Stats", "GET", "/api/employee/analytics/orders", token=self.token
        )
        self.run_test("Get Settings", "GET", "/api/employee/settings", token=self.token)
        self.run_test(
            "Get Business Info", "GET", "/api/employee/business-info", token=self.token
        )
        self.run_test(
            "Get Branding", "GET", "/api/employee/branding/config", token=self.token
        )
        self.run_test("Get Areas", "GET", "/api/employee/areas", token=self.token)
        self.run_test("Get Roles", "GET", "/api/employee/roles/roles", token=self.token)
        self.run_test(
            "Get Notifications",
            "GET",
            "/api/employee/notifications/stream",
            token=self.token,
        )
        self.run_test(
            "Get Table Assignments",
            "GET",
            "/api/employee/table-assignments",
            token=self.token,
        )
        self.run_test(
            "Get Day Periods", "GET", "/api/employee/day-periods", token=self.token
        )
        self.run_test("Get Feedback", "GET", "/api/employee/feedback", token=self.token)
        self.run_test("Get Images", "GET", "/api/employee/images", token=self.token)
        self.run_test(
            "Get Modifiers", "GET", "/api/employee/modifiers", token=self.token
        )
        self.run_test(
            "Get Realtime Status",
            "GET",
            "/api/employee/realtime/status",
            token=self.token,
        )
        self.run_test(
            "Get Admin Config", "GET", "/api/employee/admin/config", token=self.token
        )
        self.run_test(
            "Get Debug Info", "GET", "/api/employee/debug/info", token=self.token
        )

    def run(self):
        """Ejecutar tests en modo autenticado."""
        if not self.authenticate():
            return None

        self.test_authenticated_endpoints()

        passed = sum(1 for r in self.results if r["success"])
        failed = sum(1 for r in self.results if not r["success"])
        total = len(self.results)

        self.log(
            f"\n{Colors.BOLD}========================================={Colors.ENDC}"
        )
        self.log(f"{Colors.BOLD}  Resumen - Modo Autenticado{Colors.ENDC}")
        self.log(f"{Colors.BOLD}========================================={Colors.ENDC}")
        self.log(f"Total Tests: {total}")
        self.log(f"{Colors.OKGREEN}Passed: {passed}{Colors.ENDC}")
        self.log(f"{Colors.FAIL}Failed: {failed}{Colors.ENDC}")
        self.log(f"Pass Rate: {(passed / total * 100):.1f}%" if total > 0 else "N/A")

        return self.results


class SimpleTestRunner:
    def __init__(self, quiet: bool = False):
        self.quiet = quiet
        self.results = []
        self.token = None

    def log(self, msg: str, color: str = ""):
        if not self.quiet:
            print(f"{color}{msg}{Colors.ENDC}")

    def make_request(
        self,
        method: str,
        endpoint: str,
        data: dict | None = None,
        token: str | None = None,
    ) -> tuple:
        url = f"{BASE_URL}{endpoint}"
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"

        json_data = json.dumps(data).encode() if data else None
        req = Request(url, data=json_data, headers=headers, method=method)

        start_time = time.time()
        try:
            with urlopen(req, timeout=30) as response:
                duration = time.time() - start_time
                try:
                    response_data = json.loads(response.read().decode())
                except Exception:
                    response_data = {"raw": response.read().decode()}
                return response.status, response_data, duration
        except HTTPError as e:
            duration = time.time() - start_time
            try:
                error_data = json.loads(e.read().decode())
            except Exception:
                error_data = {"error": str(e)}
            return e.code, error_data, duration
        except URLError as e:
            duration = time.time() - start_time
            return 0, {"error": str(e)}, duration

    def run_test(
        self,
        name: str,
        method: str,
        endpoint: str,
        json: dict | None = None,
        token: str | None = None,
    ) -> dict:
        status, data, duration = self.make_request(method, endpoint, json, token)
        success = 200 <= status < 300
        emoji = "✓" if success else "✗"
        color = Colors.OKGREEN if success else Colors.FAIL

        self.log(
            f"{color}{emoji}{Colors.ENDC} {name:<40} [{status}] {duration * 1000:.1f}ms"
        )

        result = {
            "name": name,
            "endpoint": endpoint,
            "method": method,
            "status": status,
            "success": success,
            "duration": duration,
        }
        self.results.append(result)
        return result

    def test_health(self):
        self.log(f"\n{Colors.HEADER}Health Endpoints{Colors.ENDC}")
        self.run_test("Health Check", "GET", "/health")
        self.run_test("Client Health", "GET", "/api/client/health")
        self.run_test("Employee Health", "GET", "/api/employee/health")

    def test_client_auth(self):
        self.log(f"\n{Colors.HEADER}Client Authentication{Colors.ENDC}")
        test_email = f"test_{int(time.time())}@test.com"
        self.run_test(
            "Register",
            "POST",
            "/api/client/auth/register",
            json={"name": "Test User", "email": test_email},
        )
        self.run_test(
            "Login", "POST", "/api/client/auth/login", json={"email": test_email}
        )
        self.run_test(
            "Password Recovery",
            "POST",
            "/api/client/auth/password/recover",
            json={"email": test_email},
        )

    def test_client_menu(self):
        self.log(f"\n{Colors.HEADER}Client Menu{Colors.ENDC}")
        self.run_test("Get Menu", "GET", "/api/client/menu")
        self.run_test("Get Active Promotions", "GET", "/api/client/promotions/active")

    def test_client_orders(self):
        self.log(f"\n{Colors.HEADER}Client Orders{Colors.ENDC}")
        self.run_test(
            "Create Order",
            "POST",
            "/api/client/orders",
            json={"items": [{"menu_item_id": 1, "quantity": 1}]},
        )

    def test_client_payments(self):
        self.log(f"\n{Colors.HEADER}Client Payments{Colors.ENDC}")
        self.run_test("Get Tables", "GET", "/api/client/tables")

    def test_client_sessions(self):
        self.log(f"\n{Colors.HEADER}Client Sessions{Colors.ENDC}")
        self.run_test("Validate Session", "GET", "/api/client/sessions/validate")

    def test_client_promotions(self):
        self.log(f"\n{Colors.HEADER}Client Promotions{Colors.ENDC}")
        self.run_test("Get Active Promotions", "GET", "/api/client/promotions/active")

    def test_client_waiter_calls(self):
        self.log(f"\n{Colors.HEADER}Client Waiter Calls{Colors.ENDC}")
        self.run_test(
            "Call Waiter",
            "POST",
            "/api/client/call-waiter",
            json={"table_number": "1", "request_type": "general"},
        )

    def test_client_other(self):
        self.log(f"\n{Colors.HEADER}Client Other{Colors.ENDC}")
        self.run_test("Business Info", "GET", "/api/client/business-info")
        self.run_test("Get Tables", "GET", "/api/client/tables")
        self.run_test("Get Shortcuts", "GET", "/api/client/shortcuts")

    def test_employee_auth(self):
        self.log(f"\n{Colors.HEADER}Employee Authentication{Colors.ENDC}")
        result = self.run_test(
            "Login",
            "POST",
            "/api/employee/auth/login",
            json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
        )
        if result["success"]:
            self.token = (
                result.get("data", {}).get("access_token")
                if isinstance(result.get("data"), dict)
                else None
            )
        return self.token

    def test_employee_employees(self, token: str | None = None):
        self.log(f"\n{Colors.HEADER}Employee Management{Colors.ENDC}")
        self.run_test("Get Employees", "GET", "/api/employee/employees", token=token)
        self.run_test("Get Employee Me", "GET", "/api/employee/auth/me", token=token)
        self.run_test(
            "Get Permissions", "GET", "/api/employee/auth/permissions", token=token
        )

    def test_employee_menu(self, token: str | None = None):
        self.log(f"\n{Colors.HEADER}Employee Menu{Colors.ENDC}")
        self.run_test("Get Menu Items", "GET", "/api/employee/menu", token=token)
        self.run_test(
            "Get Categories", "GET", "/api/employee/menu/categories", token=token
        )

    def test_employee_orders(self, token: str | None = None):
        self.log(f"\n{Colors.HEADER}Employee Orders{Colors.ENDC}")
        self.run_test("Get Orders", "GET", "/api/employee/orders", token=token)
        self.run_test("Get Order 1", "GET", "/api/employee/orders/1", token=token)

    def test_employee_tables(self, token: str | None = None):
        self.log(f"\n{Colors.HEADER}Employee Tables{Colors.ENDC}")
        self.run_test("Get Tables", "GET", "/api/employee/tables", token=token)

    def test_employee_sessions(self, token: str | None = None):
        self.log(f"\n{Colors.HEADER}Employee Sessions{Colors.ENDC}")
        self.run_test(
            "Get Sessions", "GET", "/api/employee/sessions/closed", token=token
        )

    def test_employee_customers(self, token: str | None = None):
        self.log(f"\n{Colors.HEADER}Employee Customers{Colors.ENDC}")
        self.run_test(
            "Get Customers", "GET", "/api/employee/customers/search", token=token
        )

    def test_employee_reports(self, token: str | None = None):
        self.log(f"\n{Colors.HEADER}Employee Reports{Colors.ENDC}")
        self.run_test(
            "Get Sales Report", "GET", "/api/employee/reports/sales", token=token
        )
        self.run_test(
            "Get Daily Summary",
            "GET",
            "/api/employee/reports/top-products",
            token=token,
        )

    def run_all(self):
        self.test_health()
        self.test_client_auth()
        self.test_client_menu()
        self.test_client_orders()
        self.test_client_payments()
        self.test_client_sessions()
        self.test_client_promotions()
        self.test_client_waiter_calls()
        self.test_client_other()

        token = self.test_employee_auth()
        if token:
            self.test_employee_employees(token)
            self.test_employee_menu(token)
            self.test_employee_orders(token)
            self.test_employee_tables(token)
            self.test_employee_sessions(token)
            self.test_employee_customers(token)
            self.test_employee_reports(token)
        else:
            self.log(
                f"{Colors.WARNING}Skipping authenticated employee tests (login failed){Colors.ENDC}"
            )


class FullTestRunner:
    def __init__(self, quiet: bool = False):
        self.quiet = quiet
        self.session: aiohttp.ClientSession | None = None
        self.results = []
        self.employee_token: str | None = None
        self.customer_token: str | None = None

    async def setup(self):
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=30),
            headers={"Content-Type": "application/json"},
        )

    async def teardown(self):
        if self.session:
            await self.session.close()

    async def request(
        self, method: str, endpoint: str, **kwargs
    ) -> tuple[int, dict[str, Any], float]:
        url = f"{BASE_URL}{endpoint}"
        start = datetime.now()
        try:
            async with self.session.request(method, url, **kwargs) as response:
                duration = (datetime.now() - start).total_seconds()
                try:
                    data = await response.json()
                except Exception:
                    data = {"raw": await response.text()}
                return response.status, data, duration
        except aiohttp.ClientError as e:
            duration = (datetime.now() - start).total_seconds()
            return 0, {"error": str(e)}, duration

    async def authenticate_employee(self) -> bool:
        status, data, _ = await self.request(
            "POST",
            "/api/employee/auth/login",
            json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
        )
        if status == 200 and data.get("success"):
            self.employee_token = data.get("access_token")
            return True
        return False

    async def run_test(self, name: str, method: str, endpoint: str, **kwargs) -> dict:
        headers = kwargs.pop("headers", {})
        if self.employee_token and endpoint.startswith("/api/employee"):
            headers["Authorization"] = f"Bearer {self.employee_token}"
        kwargs["headers"] = headers

        status, data, duration = await self.request(method, endpoint, **kwargs)
        success = 200 <= status < 300
        emoji = "✓" if success else "✗"
        color = "\033[92m" if success else "\033[91m"

        if not self.quiet:
            print(
                f"{color}{emoji}\033[0m {name:<45} [{status}] {duration * 1000:.1f}ms"
            )

        result = {
            "name": name,
            "endpoint": endpoint,
            "method": method,
            "status": status,
            "success": success,
            "duration": duration,
        }
        self.results.append(result)
        return result

    async def test_health(self):
        print(f"\n\033[1m\033[95mHealth Endpoints\033[0m")
        await self.run_test("Health Check", "GET", "/health")
        await self.run_test("Client Health", "GET", "/api/client/health")
        await self.run_test("Employee Health", "GET", "/api/employee/health")

    async def test_all(self):
        await self.setup()
        print(
            f"\n\033[1m{Colors.BOLD}========================================={Colors.ENDC}"
        )
        print(f"{Colors.BOLD}  Pronto API Validation Test Suite{Colors.ENDC}")
        print(f"{Colors.BOLD}========================================={Colors.ENDC}")
        print(f"Base URL: {BASE_URL}")

        await self.test_health()

        await self.run_test(
            "Client Register",
            "POST",
            "/api/client/auth/register",
            json={"name": "Test", "email": f"test_{int(time.time())}@test.com"},
        )
        await self.run_test(
            "Client Login",
            "POST",
            "/api/client/auth/login",
            json={"email": "test@test.com"},
        )
        await self.run_test(
            "Client Password Recovery",
            "POST",
            "/api/client/auth/password/recover",
            json={"email": "test@test.com"},
        )
        await self.run_test(
            "Client Password Reset",
            "POST",
            "/api/client/auth/password/reset",
            json={"token": "test_token", "password": "password123"},
        )
        await self.run_test("Get Avatars", "GET", "/api/client/avatars")

        await self.run_test("Get Menu", "GET", "/api/client/menu")
        await self.run_test(
            "Get Active Promotions", "GET", "/api/client/promotions/active"
        )
        await self.run_test("Get Orders History", "GET", "/api/client/orders/history")
        await self.run_test(
            "Create Order",
            "POST",
            "/api/client/orders",
            json={"items": [{"menu_item_id": 1, "quantity": 1}]},
        )
        await self.run_test("Get Tables", "GET", "/api/client/tables")
        await self.run_test(
            "Get Active Promotions", "GET", "/api/client/promotions/active"
        )
        await self.run_test("Validate Session", "GET", "/api/client/sessions/validate")
        await self.run_test(
            "Call Waiter",
            "POST",
            "/api/client/call-waiter",
            json={"table_number": "1", "request_type": "general"},
        )
        await self.run_test("Get Notifications", "GET", "/api/client/notifications")
        await self.run_test(
            "Mark Notification Read", "POST", "/api/client/notifications/1/read"
        )
        await self.run_test("Get Business Info", "GET", "/api/client/business-info")
        await self.run_test("Get Tables", "GET", "/api/client/tables")
        await self.run_test("Get Shortcuts", "GET", "/api/client/shortcuts")

        if await self.authenticate_employee():
            await self.run_test(
                "Employee Verify Token", "GET", "/api/employee/auth/verify"
            )
            await self.run_test("Employee Get Me", "GET", "/api/employee/auth/me")
            await self.run_test(
                "Employee Get Permissions", "GET", "/api/employee/auth/permissions"
            )
            await self.run_test("Employee Logout", "POST", "/api/employee/auth/logout")
            await self.run_test("Get Employees", "GET", "/api/employee/employees")
            await self.run_test(
                "Get Employee by ID", "GET", "/api/employee/employees/1"
            )
            await self.run_test(
                "Create Employee",
                "POST",
                "/api/employee/employees",
                json={
                    "name": "New Employee",
                    "email": "new@test.com",
                    "role": "waiter",
                    "password": "password123",
                },
            )
            await self.run_test(
                "Update Employee",
                "PATCH",
                "/api/employee/employees/1",
                json={"name": "Updated Name"},
            )
            await self.run_test("Get Menu Items", "GET", "/api/employee/menu")
            await self.run_test(
                "Get Menu Categories", "GET", "/api/employee/menu/categories"
            )
            await self.run_test(
                "Create Menu Item",
                "POST",
                "/api/employee/menu",
                json={"name": "Test Item", "price": 10.99, "category_id": 1},
            )
            await self.run_test(
                "Update Menu Item",
                "PATCH",
                "/api/employee/menu/1",
                json={"price": 12.99},
            )
            await self.run_test("Get Orders", "GET", "/api/employee/orders")
            await self.run_test("Get Order by ID", "GET", "/api/employee/orders/1")
            await self.run_test(
                "Update Order Status",
                "PATCH",
                "/api/employee/orders/1/status",
                json={"status": "preparing"},
            )
            await self.run_test(
                "Get Order Items", "GET", "/api/employee/orders/1/items"
            )
            await self.run_test("Get Tables", "GET", "/api/employee/tables")
            await self.run_test("Get Table by ID", "GET", "/api/employee/tables/1")
            await self.run_test(
                "Create Table",
                "POST",
                "/api/employee/tables",
                json={"table_number": "99", "capacity": 4, "area_id": 1},
            )
            await self.run_test(
                "Update Table", "PATCH", "/api/employee/tables/1", json={"capacity": 6}
            )
            await self.run_test("Get Sessions", "GET", "/api/employee/sessions/closed")
            await self.run_test(
                "Get Session by ID", "GET", "/api/employee/sessions/closed/1"
            )
            await self.run_test(
                "Create Session",
                "POST",
                "/api/employee/sessions/closed",
                json={"table_ids": [1, 2], "customer_count": 4},
            )
            await self.run_test(
                "Close Session", "PATCH", "/api/employee/sessions/closed/1/close"
            )
            await self.run_test(
                "Get Customers", "GET", "/api/employee/customers/search"
            )
            await self.run_test(
                "Get Customer by ID", "GET", "/api/employee/customers/search/1"
            )
            await self.run_test("Get Waiter Calls", "GET", "/api/employee/waiter-calls")
            await self.run_test(
                "Acknowledge Waiter Call",
                "PATCH",
                "/api/employee/waiter-calls/1/acknowledge",
            )
            await self.run_test("Get Promotions", "GET", "/api/employee/promotions")
            await self.run_test(
                "Create Promotion",
                "POST",
                "/api/employee/promotions",
                json={
                    "code": "TEST10",
                    "discount_percent": 10,
                    "valid_from": "2024-01-01",
                    "valid_until": "2024-12-31",
                },
            )
            await self.run_test(
                "Update Promotion",
                "PATCH",
                "/api/employee/promotions/1",
                json={"discount_percent": 15},
            )
            await self.run_test(
                "Get Discount Codes", "GET", "/api/employee/discount-codes"
            )
            await self.run_test(
                "Validate Discount Code",
                "POST",
                "/api/employee/discount-codes/validate",
                json={"code": "SAVE10", "order_total": 100},
            )
            await self.run_test(
                "Get Sales Report", "GET", "/api/employee/reports/sales"
            )
            await self.run_test(
                "Get Daily Summary", "GET", "/api/employee/reports/top-products"
            )
            await self.run_test(
                "Get Popular Items", "GET", "/api/employee/reports/popular-items"
            )
            await self.run_test(
                "Get Dashboard Stats", "GET", "/api/employee/analytics/kpis"
            )
            await self.run_test(
                "Get Revenue Stats", "GET", "/api/employee/analytics/revenue"
            )
            await self.run_test(
                "Get Order Stats", "GET", "/api/employee/analytics/orders"
            )
            await self.run_test("Get Settings", "GET", "/api/employee/settings")
            await self.run_test(
                "Update Settings",
                "PATCH",
                "/api/employee/settings",
                json={"timezone": "America/New_York"},
            )
            await self.run_test(
                "Get Business Info", "GET", "/api/employee/business-info"
            )
            await self.run_test(
                "Update Business Info",
                "PATCH",
                "/api/employee/business-info",
                json={"name": "Updated Restaurant", "phone": "555-0123"},
            )
            await self.run_test("Get Branding", "GET", "/api/employee/branding/config")
            await self.run_test(
                "Update Branding",
                "PATCH",
                "/api/employee/branding/config",
                json={"primary_color": "#FF5733"},
            )
            await self.run_test("Get Areas", "GET", "/api/employee/areas")
            await self.run_test(
                "Create Area",
                "POST",
                "/api/employee/areas",
                json={"name": "Patio", "description": "Outdoor seating"},
            )
            await self.run_test("Get Roles", "GET", "/api/employee/roles/roles")
            await self.run_test("Get Role by ID", "GET", "/api/employee/roles/roles/1")
            await self.run_test(
                "Get Notifications", "GET", "/api/employee/notifications/stream"
            )
            await self.run_test(
                "Send Notification",
                "POST",
                "/api/employee/notifications/stream",
                json={"title": "Test", "message": "Test message", "type": "info"},
            )
            await self.run_test(
                "Get Table Assignments", "GET", "/api/employee/table-assignments"
            )
            await self.run_test(
                "Assign Table",
                "POST",
                "/api/employee/table-assignments",
                json={"table_id": 1, "employee_id": 1},
            )
            await self.run_test("Get Day Periods", "GET", "/api/employee/day-periods")
            await self.run_test("Get Feedback", "GET", "/api/employee/feedback")
            await self.run_test("Get Feedback by ID", "GET", "/api/employee/feedback/1")
            await self.run_test("Get Images", "GET", "/api/employee/images")
            await self.run_test("Upload Image", "POST", "/api/employee/images")
            await self.run_test("Get Modifiers", "GET", "/api/employee/modifiers")
            await self.run_test(
                "Create Modifier",
                "POST",
                "/api/employee/modifiers",
                json={"name": "Extra Cheese", "price": 1.50},
            )
            await self.run_test(
                "Get Realtime Status", "GET", "/api/employee/realtime/status"
            )
            await self.run_test("Get Admin Config", "GET", "/api/employee/admin/config")
            await self.run_test(
                "Update Admin Config",
                "PATCH",
                "/api/employee/admin/config",
                json={"maintenance_mode": False},
            )
            await self.run_test("Get Debug Info", "GET", "/api/employee/debug/info")

        await self.teardown()

        passed = sum(1 for r in self.results if r["success"])
        failed = sum(1 for r in self.results if not r["success"])
        total = len(self.results)

        print(f"\n{Colors.BOLD}========================================={Colors.ENDC}")
        print(f"{Colors.BOLD}  Test Results Summary{Colors.ENDC}")
        print(f"{Colors.BOLD}========================================={Colors.ENDC}")
        print(f"Total Tests: {total}")
        print(f"{Colors.OKGREEN}Passed: {passed}{Colors.ENDC}")
        print(f"{Colors.FAIL}Failed: {failed}{Colors.ENDC}")
        print(f"Pass Rate: {(passed / total * 100):.1f}%" if total > 0 else "N/A")
        print(f"\nEnd Time: {datetime.now().isoformat()}")

        return self.results


def check_api_health() -> bool:
    """Verificar que la API esté disponible."""
    try:
        req = Request(f"{BASE_URL}/health")
        with urlopen(req, timeout=5) as response:
            if response.status == 200:
                print(f"{Colors.OKGREEN}✓ API is reachable at {BASE_URL}{Colors.ENDC}")
                return True
    except Exception as e:
        print(f"{Colors.FAIL}✗ API is not reachable: {e}{Colors.ENDC}")
    return False


class AuthenticatedTestRunner:
    """Test runner with authentication and test data creation."""

    def __init__(self, quiet: bool = False):
        self.quiet = quiet
        self.session: aiohttp.ClientSession | None = None
        self.results = []
        self.customer_token: str | None = None
        self.customer_id: int | None = None
        self.employee_token: str | None = None
        self.session_id: int | None = None
        self.notification_id: int | None = None
        self.test_email = f"test_{int(time.time())}@test.com"

    async def setup(self):
        self.session = aiohttp.ClientSession(
            timeout=aiohttp.ClientTimeout(total=30),
            headers={"Content-Type": "application/json"},
        )

    async def teardown(self):
        if self.session:
            await self.session.close()

    async def request(
        self, method: str, endpoint: str, **kwargs
    ) -> tuple[int, dict[str, Any], float]:
        url = f"{BASE_URL}{endpoint}"
        headers = kwargs.pop("headers", {})
        if self.customer_token and endpoint.startswith("/api/client"):
            headers["Authorization"] = f"Bearer {self.customer_token}"
        elif self.employee_token and endpoint.startswith("/api/employee"):
            headers["Authorization"] = f"Bearer {self.employee_token}"
            # Debug log
            print(f"DEBUG: Sending request to {endpoint}")
            print(f"DEBUG: Token exists: {bool(self.employee_token)}")
            if self.employee_token:
                print(f"DEBUG: Token prefix: {self.employee_token[:30]}...")
        kwargs["headers"] = headers

        start = datetime.now()
        try:
            async with self.session.request(method, url, **kwargs) as response:
                duration = (datetime.now() - start).total_seconds()
                try:
                    data = await response.json()
                except Exception:
                    data = {"raw": await response.text()}
                return response.status, data, duration
        except aiohttp.ClientError as e:
            duration = (datetime.now() - start).total_seconds()
            return 0, {"error": str(e)}, duration

    async def run_test(self, name: str, method: str, endpoint: str, **kwargs) -> dict:
        status, data, duration = await self.request(method, endpoint, **kwargs)
        success = 200 <= status < 300
        emoji = "✓" if success else "✗"
        color = "\033[92m" if success else "\033[91m"

        if not self.quiet:
            print(
                f"{color}{emoji}\033[0m {name:<45} [{status}] {duration * 1000:.1f}ms"
            )

        result = {
            "name": name,
            "endpoint": endpoint,
            "method": method,
            "status": status,
            "success": success,
            "duration": duration,
        }
        self.results.append(result)
        return result

    async def authenticate_customer(self) -> bool:
        """Register and login a customer to get token."""
        self.log(f"\n{Colors.HEADER}=== Cliente: Autenticación ==={Colors.ENDC}")

        await self.run_test(
            "Register Customer",
            "POST",
            "/api/client/auth/register",
            json={"name": "Test User", "email": self.test_email},
        )

        status, data, _ = await self.request(
            "POST",
            "/api/client/auth/login",
            json={"email": self.test_email},
        )

        if status == 200 and data.get("access_token"):
            self.customer_token = data["access_token"]
            self.customer_id = data.get("user", {}).get("id")
            self.log(
                f"{Colors.OKGREEN}✓ Cliente autenticado (ID: {self.customer_id}){Colors.ENDC}"
            )
            return True

        self.log(f"{Colors.FAIL}✗ Error autenticando cliente{Colors.ENDC}")
        return False

    async def authenticate_employee(self) -> bool:
        """Login as employee to get token."""
        self.log(f"\n{Colors.HEADER}=== Empleado: Autenticación ==={Colors.ENDC}")

        # Try direct login with known working token (from earlier manual curl test)
        status, data, _ = await self.request(
            "POST",
            "/api/employee/auth/login",
            json={"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
        )

        if status == 200 and data.get("data", {}).get("access_token"):
            self.employee_token = data["data"]["access_token"]
            self.log(f"{Colors.OKGREEN}✓ Empleado autenticado{Colors.ENDC}")
            return True

        # Fallback: if login fails, skip employee tests but continue with client tests
        self.log(
            f"{Colors.WARNING}⚠ No se pudo autenticar empleado, omitiendo tests de empleado{Colors.ENDC}"
        )
        self.employee_token = None  # Explicitly set to None
        return False

    async def create_test_session(self) -> bool:
        """Create a test dining session."""
        self.log(f"\n{Colors.HEADER}=== Creando datos de prueba ==={Colors.ENDC}")

        status, data, _ = await self.request(
            "POST",
            "/api/client/sessions/open",
            json={"table_number": "1"},
        )

        if status == 200:
            self.session_id = data.get("session", {}).get("id")
            self.log(
                f"{Colors.OKGREEN}✓ Sesión creada (ID: {self.session_id}){Colors.ENDC}"
            )
            return True

        self.log(f"{Colors.WARNING}⚠ No se pudo crear sesión: {data}{Colors.ENDC}")
        return False

    async def create_test_notification(self) -> bool:
        """Create a test notification."""
        status, data, _ = await self.request(
            "POST",
            "/api/employee/notifications/stream",
            json={
                "title": "Test Notification",
                "message": "This is a test notification",
                "type": "info",
                "recipient_type": "customer",
                "customer_id": self.customer_id,
            },
        )

        if status == 200:
            self.notification_id = data.get("id")
            self.log(
                f"{Colors.OKGREEN}✓ Notificación creada (ID: {self.notification_id}){Colors.ENDC}"
            )
            return True

        self.log(f"{Colors.WARNING}⚠ No se pudo crear notificación{Colors.ENDC}")
        return False

    def log(self, msg: str, color: str = ""):
        if not self.quiet:
            print(f"{color}{msg}{Colors.ENDC}")

    async def test_authenticated_client_endpoints(self):
        """Test client endpoints that require authentication."""
        self.log(
            f"\n{Colors.HEADER}=== Cliente: Endpoints autenticados ==={Colors.ENDC}"
        )

        if self.session_id:
            await self.run_test(
                "Get Orders History",
                "GET",
                "/api/client/orders/history",
            )

            await self.run_test(
                "Get Session Orders",
                "GET",
                f"/api/client/orders/session/{self.session_id}/orders",
            )

            await self.run_test(
                "Validate Session",
                "GET",
                f"/api/client/orders/session/{self.session_id}/validate",
            )

            await self.run_test(
                "Create Order",
                "POST",
                "/api/client/orders",
                json={
                    "items": [{"menu_item_id": 1, "quantity": 1}],
                    "session_id": self.session_id,
                },
            )

        if self.notification_id:
            await self.run_test(
                "Mark Notification Read",
                "POST",
                f"/api/client/notifications/{self.notification_id}/read",
            )

    async def test_authenticated_employee_endpoints(self):
        """Test employee endpoints that require authentication."""
        self.log(
            f"\n{Colors.HEADER}=== Empleado: Endpoints autenticados ==={Colors.ENDC}"
        )

        await self.run_test(
            "Employee Verify Token",
            "GET",
            "/api/employee/auth/verify",
        )
        await self.run_test(
            "Employee Get Me",
            "GET",
            "/api/employee/auth/me",
        )
        await self.run_test(
            "Employee Get Permissions",
            "GET",
            "/api/employee/auth/permissions",
        )
        await self.run_test(
            "Get Employees",
            "GET",
            "/api/employee/employees",
        )
        await self.run_test(
            "Get Menu Items",
            "GET",
            "/api/employee/menu",
        )
        await self.run_test(
            "Get Menu Categories",
            "GET",
            "/api/employee/menu/categories",
        )
        await self.run_test(
            "Get Orders",
            "GET",
            "/api/employee/orders",
        )
        await self.run_test(
            "Get Tables",
            "GET",
            "/api/employee/tables",
        )
        await self.run_test(
            "Get Sessions",
            "GET",
            "/api/employee/sessions/closed/closed",
        )
        await self.run_test(
            "Get Customers Stats",
            "GET",
            "/api/employee/customers/search/stats",
        )
        await self.run_test(
            "Get Sales Report",
            "GET",
            "/api/employee/reports/sales",
        )
        await self.run_test(
            "Get Daily Summary",
            "GET",
            "/api/employee/reports/top-products",
        )
        await self.run_test(
            "Get Dashboard Stats",
            "GET",
            "/api/employee/analytics/kpis",
        )
        await self.run_test(
            "Get Settings",
            "GET",
            "/api/employee/settings",
        )
        await self.run_test(
            "Get Business Info",
            "GET",
            "/api/employee/business-info",
        )
        await self.run_test(
            "Get Branding",
            "GET",
            "/api/employee/branding/config",
        )
        await self.run_test(
            "Get Areas",
            "GET",
            "/api/employee/areas",
        )
        await self.run_test(
            "Get Roles Employees",
            "GET",
            "/api/employee/roles/roles/employees",
        )

        await self.run_test(
            "Employee Verify Token",
            "GET",
            "/api/employee/auth/verify",
        )
        await self.run_test(
            "Employee Get Me",
            "GET",
            "/api/employee/auth/me",
        )
        await self.run_test(
            "Employee Get Permissions",
            "GET",
            "/api/employee/auth/permissions",
        )
        await self.run_test(
            "Get Employees",
            "GET",
            "/api/employee/employees",
        )
        await self.run_test(
            "Get Menu Items",
            "GET",
            "/api/employee/menu",
        )
        await self.run_test(
            "Get Orders",
            "GET",
            "/api/employee/orders",
        )
        await self.run_test(
            "Get Tables",
            "GET",
            "/api/employee/tables",
        )
        await self.run_test(
            "Get Sessions",
            "GET",
            "/api/employee/sessions/closed/closed",
        )
        await self.run_test(
            "Get Customers Search",
            "GET",
            "/api/employee/customers/search?q=test",
        )
        await self.run_test(
            "Get Sales Report",
            "GET",
            "/api/employee/reports/sales",
        )
        await self.run_test(
            "Get Top Products",
            "GET",
            "/api/employee/reports/top-products",
        )
        await self.run_test(
            "Get Dashboard Stats",
            "GET",
            "/api/employee/analytics/kpis",
        )
        await self.run_test(
            "Get Settings",
            "GET",
            "/api/employee/settings",
        )
        await self.run_test(
            "Get Business Info",
            "GET",
            "/api/employee/business-info",
        )
        await self.run_test(
            "Get Branding",
            "GET",
            "/api/employee/branding/config",
        )
        await self.run_test(
            "Get Areas",
            "GET",
            "/api/employee/areas",
        )
        await self.run_test(
            "Get Roles",
            "GET",
            "/api/employee/roles/roles/roles",
        )
        await self.run_test(
            "Get Notifications",
            "GET",
            "/api/employee/notifications/stream",
        )

    async def run_all(self):
        """Run all tests with authentication and test data."""
        await self.setup()

        print(f"\n{Colors.BOLD}========================================={Colors.ENDC}")
        print(f"{Colors.BOLD}  Pronto API - Test Suite Autenticado{Colors.ENDC}")
        print(f"{Colors.BOLD}========================================={Colors.ENDC}")
        print(f"Base URL: {BASE_URL}")

        await self.test_health()

        await self.test_public_client_endpoints()

        await self.authenticate_customer()
        await self.create_test_session()
        await self.create_test_notification()

        await self.test_authenticated_client_endpoints()

        await self.authenticate_employee()
        await self.test_authenticated_employee_endpoints()

        await self.teardown()

        passed = sum(1 for r in self.results if r["success"])
        failed = sum(1 for r in self.results if not r["success"])
        total = len(self.results)

        print(f"\n{Colors.BOLD}========================================={Colors.ENDC}")
        print(f"{Colors.BOLD}  Test Results Summary{Colors.ENDC}")
        print(f"{Colors.BOLD}========================================={Colors.ENDC}")
        print(f"Total Tests: {total}")
        print(f"{Colors.OKGREEN}Passed: {passed}{Colors.ENDC}")
        print(f"{Colors.FAIL}Failed: {failed}{Colors.ENDC}")
        print(f"Pass Rate: {(passed / total * 100):.1f}%" if total > 0 else "N/A")
        print(f"\nEnd Time: {datetime.now().isoformat()}")

        return self.results

    async def test_health(self):
        print(f"\n{Colors.HEADER}Health Endpoints{Colors.ENDC}")
        await self.run_test("Health Check", "GET", "/health")
        await self.run_test("Client Health", "GET", "/api/client/health")
        await self.run_test("Employee Health", "GET", "/api/employee/health")

    async def test_public_client_endpoints(self):
        print(f"\n{Colors.HEADER}Client Endpoints (públicos){Colors.ENDC}")
        await self.run_test("Get Menu", "GET", "/api/client/menu")
        await self.run_test(
            "Get Active Promotions", "GET", "/api/client/promotions/active"
        )
        await self.run_test("Get Tables", "GET", "/api/client/tables")
        await self.run_test("Get Business Info", "GET", "/api/client/business-info")
        await self.run_test("Get Shortcuts", "GET", "/api/client/shortcuts")


def main():
    parser = argparse.ArgumentParser(
        description="Pronto API Test Suite",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--simple",
        "-s",
        action="store_true",
        help="Modo simple (sin dependencias async)",
    )
    parser.add_argument(
        "--full", "-f", action="store_true", help="Modo completo (con Rich y aiohttp)"
    )
    parser.add_argument(
        "--auth-mode",
        action="store_true",
        help="Modo autenticado: login, obtiene token, ejecuta tests de empleado",
    )
    parser.add_argument(
        "--check", action="store_true", help="Solo verificar que la API esté disponible"
    )
    parser.add_argument(
        "--client", action="store_true", help="Probar solo APIs de cliente"
    )
    parser.add_argument(
        "--employee",
        action="store_true",
        help="Probar solo APIs de empleado (requiere auth)",
    )
    parser.add_argument(
        "--health", action="store_true", help="Probar solo health endpoints"
    )
    parser.add_argument(
        "--output",
        "-o",
        type=str,
        metavar="FILE",
        help="Guardar resultados en archivo JSON",
    )
    parser.add_argument("--quiet", "-q", action="store_true", help="Modo silencioso")
    parser.add_argument("--verbose", "-v", action="store_true", help="Modo verboso")
    parser.add_argument(
        "--auth",
        "-a",
        action="store_true",
        help="Modo completo con autenticación y datos de prueba",
    )
    args = parser.parse_args()

    print(f"{Colors.BOLD}========================================={Colors.ENDC}")
    print(f"{Colors.BOLD}  Pronto API Test Suite{Colors.ENDC}")
    print(f"{Colors.BOLD}========================================={Colors.ENDC}")
    print(f"Base URL: {BASE_URL}")
    print(f"Start Time: {datetime.now().isoformat()}")
    print("")

    if args.check:
        check_api_health()
        return

    if args.auth_mode:
        print(f"\n{Colors.HEADER}=== MODO AUTENTICADO ==={Colors.ENDC}")
        print("Este modo primero hace login y luego prueba APIs de empleado\n")
        tester = AuthModeTester(quiet=args.quiet)
        results = tester.run()
    elif args.auth or args.full:
        if HAS_AIOHTTP:
            if args.auth:
                print(
                    f"\n{Colors.HEADER}=== MODO AUTENTICADO COMPLETO ==={Colors.ENDC}"
                )
                print("Con autenticación y creación de datos de prueba\n")
                runner = AuthenticatedTestRunner(quiet=args.quiet)
                results = asyncio.run(runner.run_all())
            else:
                runner = FullTestRunner(quiet=args.quiet)
                results = asyncio.run(runner.test_all())
        else:
            print(
                f"{Colors.WARNING}aiohttp not installed. Falling back to simple mode.{Colors.ENDC}"
            )
            runner = SimpleTestRunner(quiet=args.quiet)
            runner.run_all()
            results = runner.results
    else:
        runner = SimpleTestRunner(quiet=args.quiet)
        runner.run_all()
        results = runner.results

    if args.output and results:
        with open(args.output, "w") as f:
            json.dump(
                {
                    "timestamp": datetime.now().isoformat(),
                    "base_url": BASE_URL,
                    "results": results,
                },
                f,
                indent=2,
            )
        print(f"\n{Colors.OKGREEN}Results saved to {args.output}{Colors.ENDC}")


if __name__ == "__main__":
    main()
