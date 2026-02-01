#!/usr/bin/env python3
"""
Employee Authentication Tests - Playwright E2E
Tests JWT authentication, session management, and logout across all employee consoles.
"""

import asyncio
from datetime import datetime

from playwright.async_api import Page, async_playwright, expect


class EmployeeAuthTests:
    """E2E tests for employee authentication using Playwright"""

    def __init__(self):
        self.base_url = "http://localhost:6081"
        self.test_results = {"passed": [], "failed": [], "warnings": []}

    def log_pass(self, test_name: str):
        """Log a passing test"""
        self.test_results["passed"].append(test_name)
        print(f"✅ PASS: {test_name}")

    def log_fail(self, test_name: str, error: str):
        """Log a failing test"""
        self.test_results["failed"].append({"test": test_name, "error": error})
        print(f"❌ FAIL: {test_name}")
        print(f"   Error: {error}")

    def log_warning(self, message: str):
        """Log a warning"""
        self.test_results["warnings"].append(message)
        print(f"⚠️  WARNING: {message}")

    def print_summary(self):
        """Print test summary"""
        print("\n" + "=" * 80)
        print("EMPLOYEE AUTHENTICATION TEST SUMMARY")
        print("=" * 80)
        print(f"✅ Passed: {len(self.test_results['passed'])}")
        print(f"❌ Failed: {len(self.test_results['failed'])}")
        print(f"⚠️  Warnings: {len(self.test_results['warnings'])}")

        if self.test_results["failed"]:
            print("\nFailed Tests:")
            for failure in self.test_results["failed"]:
                print(f"  - {failure['test']}: {failure['error']}")

        print("=" * 80)

    async def test_main_login_logout(self, page: Page):
        """Test 1: Main auth login via console selector"""
        test_name = "Main Auth Login/Logout"
        try:
            # Navigate to root (console selector)
            await page.goto(f"{self.base_url}/")
            await page.wait_for_load_state("networkidle")

            # Click on Admin console link (goes directly to dashboard if already logged in)
            await page.click('a[href="/admin/dashboard"]')
            await page.wait_for_load_state("networkidle")

            # Check if we're on login or dashboard
            current_url = page.url
            if "login" in current_url:
                # Not logged in, fill the form
                await page.fill('input[name="email"]', "admin@cafeteria.test")
                await page.fill('input[name="password"]', "ChangeMe!123")
                await page.click('button[type="submit"]')
                await page.wait_for_url("**/admin/dashboard", timeout=5000)

            # Verify we're on dashboard
            await expect(page).to_have_url(f"{self.base_url}/admin/dashboard")

            # Check for employee name (not "Usuario")
            page_content = await page.content()
            if "Usuario" in page_content and "admin@cafeteria.test" not in page_content.lower():
                self.log_warning("Employee name shows as 'Usuario' instead of real name")

            # Logout
            await page.click(".header-user-btn, [data-action='user-menu']")
            await page.wait_for_timeout(500)
            await page.click("text=Cerrar Sesión")
            await page.wait_for_url("**/admin/login", timeout=5000)

            # Verify redirect to login
            await expect(page).to_have_url(f"{self.base_url}/admin/login")

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def test_waiter_login_logout(self, page: Page):
        """Test 2: Waiter console login and logout"""
        test_name = "Waiter Login/Logout"
        try:
            await page.goto(f"{self.base_url}/waiter/login")
            await page.wait_for_load_state("networkidle")

            await page.fill('input[name="email"]', "juan.mesero@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click('button[type="submit"]')
            await page.wait_for_url("**/waiter/dashboard", timeout=5000)

            # Verify dashboard loaded
            await expect(page).to_have_url(f"{self.base_url}/waiter/dashboard")

            # Check for JWT cookie
            cookies = await page.context.cookies()
            access_token = next((c for c in cookies if c["name"] == "access_token"), None)
            if not access_token:
                self.log_warning("access_token cookie not found after login")

            # Logout
            await page.goto(f"{self.base_url}/waiter/logout")
            await page.wait_for_url("**/waiter/login", timeout=5000)

            # Verify cookies cleared
            cookies_after = await page.context.cookies()
            access_token_after = next(
                (c for c in cookies_after if c["name"] == "access_token"), None
            )
            if access_token_after:
                self.log_warning("access_token cookie still present after logout")

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def test_chef_login_logout(self, page: Page):
        """Test 3: Chef console login and logout"""
        test_name = "Chef Login/Logout"
        try:
            await page.goto(f"{self.base_url}/chef/login")
            await page.wait_for_load_state("networkidle")

            await page.fill('input[name="email"]', "carlos.chef@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click('button[type="submit"]')
            await page.wait_for_url("**/chef/dashboard", timeout=5000)

            await expect(page).to_have_url(f"{self.base_url}/chef/dashboard")

            # Logout
            await page.goto(f"{self.base_url}/chef/logout")
            await page.wait_for_url("**/chef/login", timeout=5000)

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def test_cashier_login_logout(self, page: Page):
        """Test 4: Cashier console login and logout"""
        test_name = "Cashier Login/Logout"
        try:
            await page.goto(f"{self.base_url}/cashier/login")
            await page.wait_for_load_state("networkidle")

            await page.fill('input[name="email"]', "laura.cajera@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click('button[type="submit"]')
            await page.wait_for_url("**/cashier/dashboard", timeout=5000)

            await expect(page).to_have_url(f"{self.base_url}/cashier/dashboard")

            # Logout
            await page.goto(f"{self.base_url}/cashier/logout")
            await page.wait_for_url("**/cashier/login", timeout=5000)

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def test_admin_login_logout(self, page: Page):
        """Test 5: Admin console login and logout"""
        test_name = "Admin Login/Logout"
        try:
            await page.goto(f"{self.base_url}/admin/login")
            await page.wait_for_load_state("networkidle")

            await page.fill('input[name="email"]', "admin@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click('button[type="submit"]')
            await page.wait_for_url("**/admin/dashboard", timeout=5000)

            await expect(page).to_have_url(f"{self.base_url}/admin/dashboard")

            # Logout
            await page.goto(f"{self.base_url}/admin/logout")
            await page.wait_for_url("**/admin/login", timeout=5000)

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def test_system_login_logout(self, page: Page):
        """Test 6: System console login and logout"""
        test_name = "System Login/Logout"
        try:
            await page.goto(f"{self.base_url}/system/login")
            await page.wait_for_load_state("networkidle")

            await page.fill('input[name="email"]', "admin@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click('button[type="submit"]')
            await page.wait_for_url("**/system/dashboard", timeout=5000)

            await expect(page).to_have_url(f"{self.base_url}/system/dashboard")

            # Logout (system supports both GET and POST)
            await page.goto(f"{self.base_url}/system/logout")
            await page.wait_for_url("**/system/login", timeout=5000)

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def test_invalid_credentials(self, page: Page):
        """Test 7: Login with invalid credentials"""
        test_name = "Invalid Credentials"
        try:
            await page.goto(f"{self.base_url}/waiter/login")
            await page.wait_for_load_state("networkidle")

            await page.fill('input[name="email"]', "wrong@test.com")
            await page.fill('input[name="password"]', "wrongpassword")
            await page.click('button[type="submit"]')

            # Should stay on login page
            await page.wait_for_timeout(2000)
            current_url = page.url
            if "login" not in current_url:
                raise Exception(f"Expected to stay on login page, but got: {current_url}")

            # Check for error message
            page_content = await page.content()
            if "inválid" not in page_content.lower() and "error" not in page_content.lower():
                self.log_warning("No error message shown for invalid credentials")

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def test_session_persistence(self, page: Page):
        """Test 8: Session persistence across page reloads"""
        test_name = "Session Persistence"
        try:
            # Login
            await page.goto(f"{self.base_url}/waiter/login")
            await page.fill('input[name="email"]', "juan.mesero@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click('button[type="submit"]')
            await page.wait_for_url("**/waiter/dashboard", timeout=5000)

            # Reload page
            await page.reload()
            await page.wait_for_load_state("networkidle")

            # Should still be on dashboard (not redirected to login)
            current_url = page.url
            if "dashboard" not in current_url:
                raise Exception(f"Session not persisted after reload. URL: {current_url}")

            # Cleanup - logout
            await page.goto(f"{self.base_url}/waiter/logout")

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def test_unauthenticated_access(self, page: Page):
        """Test 9: Unauthenticated access to protected routes"""
        test_name = "Unauthenticated Access Protection"
        try:
            # Try to access dashboard without login
            await page.goto(f"{self.base_url}/waiter/dashboard")
            await page.wait_for_load_state("networkidle")

            # Should redirect to login
            current_url = page.url
            if "login" not in current_url:
                raise Exception(f"Expected redirect to login, but got: {current_url}")

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def test_scope_guard_enforcement(self, page: Page):
        """Test 10: Scope guard prevents cross-scope access"""
        test_name = "Scope Guard Enforcement"
        try:
            # Login as waiter
            await page.goto(f"{self.base_url}/waiter/login")
            await page.fill('input[name="email"]', "juan.mesero@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click('button[type="submit"]')
            await page.wait_for_url("**/waiter/dashboard", timeout=5000)

            # Try to access chef dashboard (different scope)
            await page.goto(f"{self.base_url}/chef/dashboard")
            await page.wait_for_load_state("networkidle")

            # Should be redirected to chef login or show error
            current_url = page.url
            if "waiter/dashboard" in current_url:
                raise Exception("Scope guard failed - waiter can access chef dashboard")

            # Cleanup
            await page.goto(f"{self.base_url}/waiter/logout")

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def test_jwt_cookie_properties(self, page: Page):
        """Test 11: JWT cookies have correct security properties"""
        test_name = "JWT Cookie Security Properties"
        try:
            await page.goto(f"{self.base_url}/waiter/login")
            await page.fill('input[name="email"]', "juan.mesero@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click('button[type="submit"]')
            await page.wait_for_url("**/waiter/dashboard", timeout=5000)

            # Check cookie properties
            cookies = await page.context.cookies()
            access_token = next((c for c in cookies if c["name"] == "access_token"), None)

            if not access_token:
                raise Exception("access_token cookie not found")

            # Verify cookie properties
            if not access_token.get("httpOnly"):
                self.log_warning("access_token cookie is not httpOnly")

            if access_token.get("path") != "/":
                self.log_warning(f"access_token path is {access_token.get('path')}, expected /")

            # Cleanup
            await page.goto(f"{self.base_url}/waiter/logout")

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def test_logout_clears_all_state(self, page: Page):
        """Test 12: Logout clears cookies and prevents access"""
        test_name = "Logout Clears All State"
        try:
            # Login
            await page.goto(f"{self.base_url}/waiter/login")
            await page.fill('input[name="email"]', "juan.mesero@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click('button[type="submit"]')
            await page.wait_for_url("**/waiter/dashboard", timeout=5000)

            # Logout
            await page.goto(f"{self.base_url}/waiter/logout")
            await page.wait_for_url("**/waiter/login", timeout=5000)

            # Try to access dashboard again
            await page.goto(f"{self.base_url}/waiter/dashboard")
            await page.wait_for_load_state("networkidle")

            # Should redirect to login
            current_url = page.url
            if "dashboard" in current_url and "login" not in current_url:
                raise Exception(f"Can still access dashboard after logout: {current_url}")

            self.log_pass(test_name)

        except Exception as e:
            self.log_fail(test_name, str(e))

    async def run_all_tests(self, headless: bool = True):
        """Run all authentication tests"""
        print("=" * 80)
        print("EMPLOYEE AUTHENTICATION E2E TESTS")
        print("=" * 80)
        print(f"Start Time: {datetime.utcnow().isoformat()}")
        print(f"Headless: {headless}")
        print("")

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=headless)
            context = await browser.new_context()
            page = await context.new_page()

            try:
                # Run all tests
                await self.test_main_login_logout(page)
                await self.test_waiter_login_logout(page)
                await self.test_chef_login_logout(page)
                await self.test_cashier_login_logout(page)
                await self.test_admin_login_logout(page)
                await self.test_system_login_logout(page)
                await self.test_invalid_credentials(page)
                await self.test_session_persistence(page)
                await self.test_unauthenticated_access(page)
                await self.test_scope_guard_enforcement(page)
                await self.test_jwt_cookie_properties(page)
                await self.test_logout_clears_all_state(page)

            finally:
                await context.close()
                await browser.close()

        self.print_summary()

        # Return exit code
        return 1 if self.test_results["failed"] else 0


async def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description="Employee Authentication E2E Tests")
    parser.add_argument("--no-headless", action="store_true", help="Run with browser UI visible")
    args = parser.parse_args()

    tests = EmployeeAuthTests()
    exit_code = await tests.run_all_tests(headless=not args.no_headless)
    raise SystemExit(exit_code)


if __name__ == "__main__":
    asyncio.run(main())
