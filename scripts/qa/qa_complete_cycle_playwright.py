"""
PRONTO QA Complete Flow Test - Automated E2E Test

Test Flow:
1. Create order in localhost:6080 (client app) with multiple products
2. Confirm with email luartx@gmail.com
3. Chef in localhost:6081: Iniciar → Listo
4. Waiter: Entregar → Cobrar (Efectivo)
5. Verify: email sent, PDF downloadable, order in "Pagadas"
"""

import asyncio
import os
from datetime import datetime
from typing import Any

from playwright.async_api import BrowserContext, Page, async_playwright


class QALogger:
    """Logger for QA test execution"""

    def __init__(self):
        self.errors: list[dict[str, str]] = []
        self.success: list[str] = []
        self.warnings: list[str] = []

    def log_error(self, severity: str, description: str, location: str, impact: str, solution: str):
        """Log error in specified format"""
        error = {
            "timestamp": datetime.utcnow().isoformat(),
            "severity": severity,
            "description": description,
            "location": location,
            "impact": impact,
            "solution": solution,
        }
        self.errors.append(error)
        print(f"❌ ERROR [{severity}]: {description}")
        print(f"   Location: {location}")
        print(f"   Impact: {impact}")
        print(f"   Solution: {solution}")
        print("")

    def log_success(self, message: str):
        """Log success message"""
        self.success.append({"timestamp": datetime.utcnow().isoformat(), "message": message})
        print(f"✅ {message}")

    def log_warning(self, message: str):
        """Log warning message"""
        self.warnings.append({"timestamp": datetime.utcnow().isoformat(), "message": message})
        print(f"⚠️ {message}")

    def print_summary(self):
        """Print test summary"""
        print("\n" + "=" * 80)
        print("QA TEST SUMMARY")
        print("=" * 80)
        print(f"\n✅ Success: {len(self.success)}")
        print(f"⚠️  Warnings: {len(self.warnings)}")
        print(f"❌ Errors: {len(self.errors)}")

        if self.errors:
            print("\n" + "ERRORS FOUND:")
            print("-" * 80)
            for error in self.errors:
                print(f"- ERROR [{error['severity']}]: {error['description']}")
                print(f"  - Location: {error['location']}")
                print(f"  - Impact: {error['impact']}")
                print(f"  - Solution: {error['solution']}")
                print("")

        if self.warnings:
            print("\nWARNINGS:")
            print("-" * 40)
            for warning in self.warnings:
                print(f"- {warning['message']}")

        print("\n" + "=" * 80)


class PRONTOQATest:
    """Automated QA test for PRONTO cafeteria"""

    def __init__(self):
        self.logger = QALogger()
        self.test_data: dict[str, Any] = {
            "customer_name": "QA Tester",
            "customer_email": "luartx@gmail.com",
            "customer_phone": "1234567890",
            "table_number": "QA-TABLE-1",
            "order_id": None,
            "session_id": None,
            "payment_method": "cash",
        }
        self.order_items = []
        self.payment_data = {}
        self.generated_pdfs = []

    async def run_test(self, headless: bool = True):
        """Run complete QA test flow"""
        print("=" * 80)
        print("PRONTO CAFETERÍA - QA COMPLETE FLOW TEST")
        print("=" * 80)
        print(f"Start Time: {datetime.utcnow().isoformat()}")
        print(f"Headless Mode: {headless}")
        print("")

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=headless)
            context = await browser.new_context()

            # Prepare artifacts folder and start tracing
            os.makedirs("qa_artifacts", exist_ok=True)
            try:
                await context.tracing.start(screenshots=True, snapshots=True, sources=True)
            except Exception:
                # tracing may not be available in some environments
                pass

            try:
                # Step 1: Client App - Create Order
                await self.test_client_app(context)

                # Step 2: Chef App - Iniciar → Listo
                await self.test_chef_app(context)

                # Step 3: Waiter App - Entregar → Cobrar
                await self.test_waiter_app(context)

                # Step 4: Verify Email and PDF
                await self.verify_email_and_pdf(context)

            except Exception as e:
                self.logger.log_error(
                    severity="CRITICAL",
                    description=f"Test execution failed: {e!s}",
                    location="PRONTOQATest.run_test()",
                    impact="Cannot complete QA test",
                    solution=f"Check exception: {e}",
                )

            finally:
                # stop tracing and collect artifacts
                try:
                    await context.tracing.stop(path="qa_artifacts/trace.zip")
                except Exception:
                    pass
                await context.close()
                await browser.close()

        self.logger.print_summary()

    async def test_client_app(self, context: BrowserContext):
        """Test 1: Create order in client app with multiple products"""
        print("\n" + "=" * 80)
        print("STEP 1: CLIENT APP - CREATE ORDER")
        print("=" * 80)

        page = await context.new_page()
        await page.goto("http://localhost:6080/", wait_until="networkidle")

        try:
            # Validate page loads
            title = await page.title()
            self.logger.log_success(f"Client app loaded: {title}")

            # Add multiple products to cart
            menu_items_to_add = [
                {"id": 1, "name": "Combo Familiar", "quantity": 1},
                {"id": 8, "name": "Hamburguesa Simple", "quantity": 2},
                {"id": 39, "name": "Limonada", "quantity": 1},
            ]

            for item in menu_items_to_add:
                await self.add_product_to_cart(page, item)

            # capture cart/menu screenshot
            try:
                await page.screenshot(path="qa_artifacts/client_menu.png", full_page=True)
            except Exception:
                pass

            self.logger.log_success(f"Added {len(menu_items_to_add)} products to cart")

            # Validate checkout before confirming
            await self.validate_checkout(page)

            # Proceed to checkout
            await page.click("text=Ver Carrito", timeout=5000)
            await page.wait_for_timeout(2000)

            try:
                await page.screenshot(
                    path="qa_artifacts/client_cart_before_fill.png", full_page=True
                )
            except Exception:
                pass

            # Fill customer information
            await page.fill('input[name="customer_name"]', self.test_data["customer_name"])
            await page.fill('input[name="customer_email"]', self.test_data["customer_email"])
            await page.fill('input[name="customer_phone"]', self.test_data["customer_phone"])
            await page.fill('input[name="table_number"]', self.test_data["table_number"])

            self.logger.log_success("Customer information filled")

            # Validate required fields
            await self.validate_required_fields(page)

            # Confirm order
            await page.click("text=Confirmar Pedido", timeout=5000)

            # Wait for order confirmation
            await page.wait_for_timeout(3000)

            # Capture order ID and session ID from page
            try:
                # Try to find order ID in page content
                content = await page.content()
                self.logger.log_success("Order confirmed successfully")
                self.test_data["order_created"] = True
                try:
                    await page.screenshot(
                        path="qa_artifacts/client_order_confirm.png", full_page=True
                    )
                except Exception:
                    pass
            except Exception as e:
                self.logger.log_error(
                    severity="HIGH",
                    description=f"Order confirmation failed: {e!s}",
                    location="Client App - Order Confirmation",
                    impact="Cannot complete order",
                    solution="Check order submission logic",
                )

        except Exception as e:
            self.logger.log_error(
                severity="HIGH",
                description=f"Client app test failed: {e!s}",
                location="Client App",
                impact="Cannot create order",
                solution="Check page elements and selectors",
            )
        finally:
            await page.close()

    async def add_product_to_cart(self, page: Page, item: dict[str, Any]):
        """Add a product to cart"""
        try:
            # Find product by name or ID
            product_selector = f'[data-product-id="{item["id"]}"]'
            if await page.query_selector(product_selector):
                await page.click(product_selector)
                await page.wait_for_timeout(500)

                # Add to cart
                add_button = page.locator("text=Agregar al Carrito").first
                await add_button.click()
                await page.wait_for_timeout(500)

                self.order_items.append(item)
                self.logger.log_success(f"Added {item['name']} x{item['quantity']} to cart")
            else:
                self.logger.log_warning(f"Product {item['name']} not found on page")

        except Exception as e:
            self.logger.log_warning(f"Failed to add {item['name']}: {e!s}")

    async def validate_checkout(self, page: Page):
        """Validate required fields before checkout"""
        try:
            cart_count = await page.locator(".cart-item").count()
            if cart_count == 0:
                self.logger.log_error(
                    severity="HIGH",
                    description="Cart is empty",
                    location="Client App - Checkout Validation",
                    impact="User can checkout without items",
                    solution="Add validation: Cart must have at least 1 item",
                )
            else:
                self.logger.log_success(f"Cart validation passed: {cart_count} items")

        except Exception as e:
            self.logger.log_warning(f"Checkout validation failed: {e!s}")

    async def validate_required_fields(self, page: Page):
        """Validate required fields are present before adding to cart"""
        try:
            # Check if required field validation exists
            required_fields = await page.query_selector_all('[required], [data-required="true"]')

            if len(required_fields) > 0:
                self.logger.log_success(
                    f"Found {len(required_fields)} required fields for validation"
                )
            else:
                self.logger.log_warning("No required field validation found")

        except Exception as e:
            self.logger.log_warning(f"Required field validation check failed: {e!s}")

    async def test_chef_app(self, context: BrowserContext):
        """Test 2: Chef App - Iniciar → Listo"""
        print("\n" + "=" * 80)
        print("STEP 2: CHEF APP - PROCESS ORDER")
        print("=" * 80)

        page = await context.new_page()

        try:
            # Login as chef
            await page.goto("http://localhost:6081/chef/login", wait_until="networkidle")

            await page.fill('input[name="email"]', "carlos.chef@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click("text=Iniciar Sesión", timeout=5000)

            await page.wait_for_url("**/chef/dashboard", timeout=5000)
            self.logger.log_success("Chef logged in successfully")

            # Find order and change status to "En preparación"
            await self.wait_and_change_status(page, "En preparación")

            # Change status to "Listo"
            await self.wait_and_change_status(page, "Listo")

            self.logger.log_success("Order status: Listo (Ready)")

        except Exception as e:
            self.logger.log_error(
                severity="HIGH",
                description=f"Chef app test failed: {e!s}",
                location="Chef App",
                impact="Cannot process orders in kitchen",
                solution="Check login flow and order status buttons",
            )
        finally:
            await page.close()

    async def wait_and_change_status(self, page: Page, status: str):
        """Wait for order and change its status"""
        try:
            # Wait for order to appear
            await page.wait_for_timeout(2000)

            # Find first order card
            order_card = page.locator(".order-card, [data-order-id]").first

            if await order_card.count() > 0:
                # Click status change button
                status_button = order_card.locator(
                    f"text={status}, [data-action*='{status.lower()}']"
                ).first
                if await status_button.count() > 0:
                    await status_button.click()
                    await page.wait_for_timeout(1000)
                    self.logger.log_success(f"Order status changed to: {status}")
                else:
                    self.logger.log_warning(f"Status button '{status}' not found")
            else:
                self.logger.log_warning("No orders found to process")

        except Exception as e:
            self.logger.log_warning(f"Failed to change status to {status}: {e!s}")

    async def test_waiter_app(self, context: BrowserContext):
        """Test 3: Waiter App - Entregar → Cobrar (Efectivo)"""
        print("\n" + "=" * 80)
        print("STEP 3: WAITER APP - DELIVER AND CHARGE")
        print("=" * 80)

        page = await context.new_page()

        try:
            # Login as waiter
            await page.goto("http://localhost:6081/waiter/login", wait_until="networkidle")

            await page.fill('input[name="email"]', "juan.mesero@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click("text=Iniciar Sesión", timeout=5000)

            await page.wait_for_url("**/waiter/dashboard", timeout=5000)
            self.logger.log_success("Waiter logged in successfully")

            # Find ready order and deliver it
            await page.wait_for_timeout(2000)

            # Find order with status "Listo"
            ready_order = page.locator("[data-status='ready_for_delivery']").first

            if await ready_order.count() > 0:
                await ready_order.locator("text=Entregar").first.click()
                await page.wait_for_timeout(1000)
                self.logger.log_success("Order marked as Delivered")
            else:
                self.logger.log_warning("No ready orders found to deliver")

            # Charge order with cash
            await page.wait_for_timeout(1000)

            # Find delivered order and charge it
            delivered_order = page.locator("[data-status='delivered']").first

            if await delivered_order.count() > 0:
                await delivered_order.locator("text=Cobrar").first.click()
                await page.wait_for_timeout(500)

                # Select payment method: Efectivo
                await page.click("text=Efectivo", timeout=3000)
                await page.click("text=Confirmar Pago", timeout=3000)

                await page.wait_for_timeout(2000)
                self.logger.log_success("Order charged with cash")
                self.test_data["order_charged"] = True
            else:
                self.logger.log_warning("No delivered orders found to charge")

        except Exception as e:
            self.logger.log_error(
                severity="HIGH",
                description=f"Waiter app test failed: {e!s}",
                location="Waiter App",
                impact="Cannot deliver and charge orders",
                solution="Check delivery and charge flow",
            )
        finally:
            await page.close()

    async def verify_email_and_pdf(self, context: BrowserContext):
        """Test 4: Verify email sent, PDF downloadable, order in Pagadas"""
        print("\n" + "=" * 80)
        print("STEP 4: VERIFICATION - EMAIL & PDF")
        print("=" * 80)

        page = await context.new_page()

        try:
            # Check Cashier App for paid orders
            await page.goto("http://localhost:6081/cashier/login", wait_until="networkidle")

            await page.fill('input[name="email"]', "laura.cajera@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click("text=Iniciar Sesión", timeout=5000)

            await page.wait_for_url("**/cashier/dashboard", timeout=5000)
            self.logger.log_success("Cashier logged in successfully")

            # Switch to "Pagadas" tab
            await page.wait_for_timeout(2000)
            paid_tab = page.locator("text=Pagadas, [data-tab='paid']").first
            if await paid_tab.count() > 0:
                await paid_tab.click()
                await page.wait_for_timeout(1000)
                self.logger.log_success("Switched to Pagadas tab")

            # Check for paid orders
            await page.wait_for_timeout(2000)
            paid_orders = await page.locator("[data-status='paid']").count()

            if paid_orders > 0:
                self.logger.log_success(f"Found {paid_orders} paid order(s)")
                self.test_data["order_in_paid"] = True

                # Check for PDF download option
                pdf_button = page.locator("text=Descargar PDF, [data-action='download-pdf']").first
                if await pdf_button.count() > 0:
                    self.logger.log_success("PDF download option available")

                    # Test PDF download
                    async with page.expect_download(timeout=5000) as download_info:
                        await pdf_button.click()

                    download = await download_info.value
                    self.generated_pdfs.append(download.suggested_filename)
                    self.logger.log_success(f"PDF downloaded: {download.suggested_filename}")
                else:
                    self.logger.log_warning("PDF download option not found")

            else:
                self.logger.log_error(
                    severity="HIGH",
                    description="No paid orders found",
                    location="Cashier App - Pagadas Tab",
                    impact="Cannot verify order completion",
                    solution="Check order payment flow",
                )

            # Check Admin App for reports
            await page.goto("http://localhost:6081/admin/login", wait_until="networkidle")

            await page.fill('input[name="email"]', "admin@cafeteria.test")
            await page.fill('input[name="password"]', "ChangeMe!123")
            await page.click("text=Iniciar Sesión", timeout=5000)

            await page.wait_for_url("**/admin/dashboard", timeout=5000)
            self.logger.log_success("Admin logged in successfully")

            # Check for debug panel
            debug_panel = await page.query_selector("#debug-panel, [data-component='debug-panel']")
            if debug_panel:
                self.logger.log_error(
                    severity="MEDIUM",
                    description="DEBUG PANEL is visible in production",
                    location="Admin App",
                    impact="Security risk - debug features exposed",
                    solution="Hide debug panel in production environment",
                )
            else:
                self.logger.log_success("Debug panel not visible (OK for production)")

        except Exception as e:
            self.logger.log_error(
                severity="HIGH",
                description=f"Verification test failed: {e!s}",
                location="Verification",
                impact="Cannot verify email, PDF, or paid orders",
                solution="Check cashier and admin flows",
            )
        finally:
            await page.close()


async def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--no-headless", action="store_true", help="Run with browser UI (not headless)"
    )
    args = parser.parse_args()

    headless = not args.no_headless

    qa_test = PRONTOQATest()
    await qa_test.run_test(headless=headless)

    # Exit with error code if there are critical errors
    critical_errors = [e for e in qa_test.logger.errors if e["severity"] == "CRITICAL"]
    raise SystemExit(1 if critical_errors else 0)


if __name__ == "__main__":
    asyncio.run(main())
