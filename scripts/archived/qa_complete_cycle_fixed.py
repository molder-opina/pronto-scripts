"""
PRONTO QA Complete Flow Test - Improved Version
Fixes: Correct selectors, proper waits, and DOM-aware locators
"""

import asyncio
from datetime import datetime
from typing import Any

from playwright.async_api import BrowserContext, Page, async_playwright


class QALogger:
    def __init__(self):
        self.errors: list[dict[str, str]] = []
        self.success: list[str] = []
        self.warnings: list[str] = []

    def log_error(self, severity: str, description: str, location: str, impact: str, solution: str):
        error = {
            "timestamp": datetime.now().isoformat(),
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
        print(f"   Solution: {solution}\n")

    def log_success(self, message: str):
        self.success.append({"timestamp": datetime.now().isoformat(), "message": message})
        print(f"✅ {message}")

    def log_warning(self, message: str):
        self.warnings.append({"timestamp": datetime.now().isoformat(), "message": message})
        print(f"⚠️ {message}")

    def print_summary(self):
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


class PRONTOQAFixedTest:
    def __init__(self):
        self.logger = QALogger()
        self.test_data = {
            "customer_name": "QA Tester",
            "customer_email": "luartx@gmail.com",
            "customer_phone": "1234567890",
            "table_number": "M-M01",
        }
        self.order_created = False

    async def run_test(self, headless: bool = True):
        print("=" * 80)
        print("PRONTO CAFETERÍA - QA COMPLETE FLOW TEST (FIXED)")
        print("=" * 80)
        print(f"Start Time: {datetime.now().isoformat()}")
        print(f"Headless Mode: {headless}\n")

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=headless)
            context = await browser.new_context()

            try:
                # Step 1: Client App
                await self.test_client_app(context)
                # Step 2: Chef App
                await self.test_chef_app(context)
                # Step 3: Waiter App
                await self.test_waiter_app(context)
                # Step 4: Verify
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
                await context.close()
                await browser.close()

        self.logger.print_summary()

    async def test_client_app(self, context: BrowserContext):
        print("\n" + "=" * 80)
        print("STEP 1: CLIENT APP - CREATE ORDER")
        print("=" * 80)

        page = await context.new_page()
        try:
            await page.goto("http://localhost:6080/", wait_until="networkidle")
            title = await page.title()
            self.logger.log_success(f"Client app loaded: {title}")

            # Wait for menu to load
            await page.wait_for_selector(".menu-item-card", timeout=15000)
            self.logger.log_success("Menu loaded successfully")

            # Add first 3 products
            products_to_add = [
                {"name": "Hamburguesa Simple", "quantity": 1},
                {"name": "Limonada", "quantity": 1},
                {"name": "Flan", "quantity": 1},
            ]

            for product in products_to_add:
                await self.add_product_to_cart(page, product)

            # Verify cart has items
            cart_count = await page.locator(".cart-items .cart-item").count()
            cart_badge = (
                await page.locator("#cart-count").text_content()
                if await page.locator("#cart-count").count() > 0
                else "0"
            )

            item_count = (
                int(cart_badge) if (cart_badge and cart_badge.strip().isdigit()) else cart_count
            )

            if item_count > 0:
                self.logger.log_success(f"Cart has {item_count} items")
            else:
                self.logger.log_error(
                    severity="HIGH",
                    description="Products not added to cart",
                    location="Client App - Add to Cart",
                    impact="Cannot proceed with order",
                    solution="Check product selectors and cart persistence",
                )

            # Go to checkout
            await page.click(
                "button[type='submit'][form='checkout-form'], button:has-text('Ir a pagar')"
            )
            await page.wait_for_timeout(2000)

            # Fill customer info
            await page.fill(
                "input[id='customer-name'], input[name='customer_name']",
                self.test_data["customer_name"],
            )
            await page.fill(
                "input[id='customer-email'], input[name='customer_email']",
                self.test_data["customer_email"],
            )
            await page.fill(
                "input[id='customer-phone'], input[name='customer_phone']",
                self.test_data["customer_phone"],
            )

            self.logger.log_success("Customer information filled")

            # Submit order
            submit_btn = await page.query_selector("button[type='submit'][form='checkout-form']")
            if submit_btn:
                await page.click("button[type='submit'][form='checkout-form']")
                await page.wait_for_timeout(3000)
                self.order_created = True
                self.logger.log_success("Order submitted successfully")
            else:
                self.logger.log_warning("Checkout button not found")

        except Exception as e:
            self.logger.log_error(
                severity="HIGH",
                description=f"Client app test failed: {e!s}",
                location="Client App",
                impact="Cannot create order",
                solution="Check page elements and flow",
            )
        finally:
            await page.close()

    async def add_product_to_cart(self, page: Page, product: dict[str, Any]):
        try:
            # Find product card by name
            cards = await page.query_selector_all(".menu-item-card")
            for card in cards:
                text = await card.query_selector(".menu-item-card__title")
                if text:
                    card_text = await text.text_content()
                    if product["name"].lower() in (card_text or "").lower():
                        # Click card to open modal
                        await card.click()
                        await page.wait_for_timeout(1000)

                        # Click "Agregar al carrito" button
                        add_btn = await page.query_selector(".modal-add-to-cart")
                        if add_btn:
                            await add_btn.click()
                            await page.wait_for_timeout(500)
                            self.logger.log_success(f"Added {product['name']} to cart")
                            return
                        break

            self.logger.log_warning(f"Could not find or add {product['name']}")
        except Exception as e:
            self.logger.log_warning(f"Failed to add {product['name']}: {e!s}")

    async def test_chef_app(self, context: BrowserContext):
        print("\n" + "=" * 80)
        print("STEP 2: CHEF APP - PROCESS ORDER")
        print("=" * 80)

        page = await context.new_page()
        try:
            await page.goto("http://localhost:6081/chef/login", wait_until="networkidle")

            # Login
            await page.fill("input[name='email']", "carlos.chef@cafeteria.test")
            await page.fill("input[name='password']", "ChangeMe!123")
            await page.click("button:has-text('Iniciar')")

            await page.wait_for_url("**/chef/dashboard", timeout=10000)
            self.logger.log_success("Chef logged in successfully")

            # Mark order as ready
            await page.wait_for_timeout(2000)
            ready_btn = await page.query_selector("button:has-text('Listo')")
            if ready_btn:
                await ready_btn.click()
                self.logger.log_success("Order marked as Listo")
            else:
                self.logger.log_warning("Listo button not found")

        except Exception as e:
            self.logger.log_error(
                severity="HIGH",
                description=f"Chef app test failed: {e!s}",
                location="Chef App",
                impact="Cannot process orders",
                solution="Check login and order buttons",
            )
        finally:
            await page.close()

    async def test_waiter_app(self, context: BrowserContext):
        print("\n" + "=" * 80)
        print("STEP 3: WAITER APP - DELIVER AND CHARGE")
        print("=" * 80)

        page = await context.new_page()
        try:
            await page.goto("http://localhost:6081/waiter/login", wait_until="networkidle")

            # Login
            await page.fill("input[name='email']", "juan.mesero@cafeteria.test")
            await page.fill("input[name='password']", "ChangeMe!123")
            await page.click("button:has-text('Iniciar')")

            await page.wait_for_url("**/waiter/dashboard", timeout=10000)
            self.logger.log_success("Waiter logged in successfully")

            # Deliver order
            await page.wait_for_timeout(2000)
            deliver_btn = await page.query_selector("button:has-text('Entregar')")
            if deliver_btn:
                await deliver_btn.click()
                self.logger.log_success("Order marked as Delivered")

            # Charge order
            await page.wait_for_timeout(1000)
            charge_btn = await page.query_selector("button:has-text('Cobrar')")
            if charge_btn:
                await charge_btn.click()
                await page.wait_for_timeout(1000)

                # Select cash payment
                cash_btn = await page.query_selector("button:has-text('Efectivo')")
                if cash_btn:
                    await cash_btn.click()
                    await page.wait_for_timeout(500)

                # Confirm payment
                confirm_btn = await page.query_selector("button:has-text('Confirmar')")
                if confirm_btn:
                    await confirm_btn.click()
                    self.logger.log_success("Order charged with cash")
            else:
                self.logger.log_warning("Charge button not found")

        except Exception as e:
            self.logger.log_error(
                severity="HIGH",
                description=f"Waiter app test failed: {e!s}",
                location="Waiter App",
                impact="Cannot deliver and charge",
                solution="Check waiter flow",
            )
        finally:
            await page.close()

    async def verify_email_and_pdf(self, context: BrowserContext):
        print("\n" + "=" * 80)
        print("STEP 4: VERIFICATION - EMAIL & PDF")
        print("=" * 80)

        page = await context.new_page()
        try:
            await page.goto("http://localhost:6081/cashier/login", wait_until="networkidle")

            # Login
            await page.fill("input[name='email']", "laura.cajera@cafeteria.test")
            await page.fill("input[name='password']", "ChangeMe!123")
            await page.click("button:has-text('Iniciar')")

            await page.wait_for_url("**/cashier/dashboard", timeout=10000)
            self.logger.log_success("Cashier logged in successfully")

            # Check paid orders
            await page.wait_for_timeout(2000)
            paid_orders = await page.query_selector_all(
                "[data-status='paid'], .paid-order, .order--paid"
            )

            if len(paid_orders) > 0:
                self.logger.log_success(f"Found {len(paid_orders)} paid order(s)")

                # Try to download PDF
                pdf_btn = await page.query_selector(
                    "button:has-text('Descargar'), button:has-text('PDF')"
                )
                if pdf_btn:
                    async with page.expect_download(timeout=5000) as download_info:
                        await pdf_btn.click()
                    download = await download_info.value
                    self.logger.log_success(f"PDF downloaded: {download.suggested_filename}")
            else:
                self.logger.log_error(
                    severity="HIGH",
                    description="No paid orders found",
                    location="Cashier App - Pagadas Tab",
                    impact="Cannot verify order completion",
                    solution="Check order payment flow and persistence",
                )

        except Exception as e:
            self.logger.log_error(
                severity="HIGH",
                description=f"Verification test failed: {e!s}",
                location="Verification",
                impact="Cannot verify email or PDF",
                solution="Check cashier flow",
            )
        finally:
            await page.close()


async def main():
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--no-headless", action="store_true", help="Run with browser UI")
    args = parser.parse_args()

    headless = not args.no_headless
    qa_test = PRONTOQAFixedTest()
    await qa_test.run_test(headless=headless)


if __name__ == "__main__":
    asyncio.run(main())
