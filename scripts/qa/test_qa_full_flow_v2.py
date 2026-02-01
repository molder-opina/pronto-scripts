"""
PRONTO QA Complete Flow Test V2 - Pure UI
-----------------------------------------
This test automates the full order lifecycle using ONLY UI interactions:
1. Client: Create Order (UI -> Add to Cart -> Checkout)
2. Waiter: Accept & Deliver (UI -> Dashboard Buttons)
3. Chef: Prepare & Ready (UI -> Dashboard Buttons)
4. Cashier: Verify & Pay (UI -> Payment Modal -> Cash)

It relies on the exact selectors found in the source code.
"""

import asyncio
import re
import time

from playwright.async_api import BrowserContext, Page, async_playwright, expect

# Configuration
BASE_URL_CLIENT = "http://localhost:6080"
BASE_URL_EMPLOYEE = "http://localhost:6081"
HEADLESS = True  # Set to False to watch the browser actions


class QALogger:
    def __init__(self):
        self.errors = []
        self.success = []
        self.warnings = []

    def log_success(self, msg):
        print(f"✅ {msg}")
        self.success.append(msg)

    def log_warning(self, msg):
        print(f"⚠️  {msg}")
        self.warnings.append(msg)

    def log_error(self, msg, fatal=False):
        print(f"❌ {msg}")
        self.errors.append(msg)
        if fatal:
            raise RuntimeError(msg)

    def summary(self):
        print("\n=== QA TEST SUMMARY ===")
        print(f"Success: {len(self.success)}")
        print(f"Warnings: {len(self.warnings)}")
        print(f"Errors: {len(self.errors)}")
        if self.errors:
            print("\nErrors detail:")
            for e in self.errors:
                print(f"- {e}")
        return len(self.errors) == 0


class ProntoQATestUI:
    def __init__(self):
        self.logger = QALogger()
        self.data = {
            "customer_name": "QA Auto UI",
            "customer_email": "qa.ui@test.local",
            "table_number": "99",
            "order_id": None,
        }

    async def run(self):
        print(f"Starting Pronto QA UI Test (Headless: {HEADLESS})")
        async with async_playwright() as p:
            # Launch with permissions for clipboard/notifications if needed
            browser = await p.chromium.launch(
                headless=HEADLESS, args=["--no-sandbox", "--disable-setuid-sandbox"]
            )
            context = await browser.new_context(
                viewport={"width": 1280, "height": 800}, ignore_https_errors=True
            )

            try:
                # 1. Client: Create Order
                await self.step_client_create_order(context)

                if not self.data["order_id"]:
                    self.logger.log_error("Stopping test: No Order ID created", fatal=True)

                # 2. Waiter: Accept
                await self.step_waiter_accept(context)

                # 3. Chef: Prepare -> Ready
                await self.step_chef_process(context)

                # 4. Waiter: Deliver
                await self.step_waiter_deliver(context)

                # 5. Cashier: Pay
                await self.step_cashier_pay(context)

            except Exception as e:
                self.logger.log_error(f"Test crashed: {e}")
                import traceback

                traceback.print_exc()
                try:
                    # Capture screenshot on failure
                    ts = int(time.time())
                    path = f"qa_error_{ts}.png"
                    # Attempt to get the current active page or create a new one for screenshot
                    if context.pages:
                        await context.pages[0].screenshot(path=path)
                    else:
                        temp_page = await context.new_page()
                        await temp_page.screenshot(path=path)
                        await temp_page.close()
                    print(f"Screenshot saved to {path}")
                except Exception as screenshot_e:
                    print(f"Could not capture screenshot: {screenshot_e}")
                raise e  # Re-raise the exception after logging and screenshot attempt
            finally:
                await context.close()
                await browser.close()
                self.logger.summary()

    async def step_client_create_order(self, context: BrowserContext):
        print("\n--- STEP 1: CLIENT CREATE ORDER (UI) ---")
        page = await context.new_page()
        try:
            await page.goto(BASE_URL_CLIENT)
            await page.wait_for_load_state("networkidle")

            # 1. Add item to cart
            # Target "Pollo a la Parrilla" to avoid modifiers (known from previous tests)
            # fallback to any item if not found
            target_item = page.locator(".menu-item-card", has_text="Pollo a la Parrilla").first
            if await target_item.count() == 0:
                print("Pollo a la Parrilla not found, using first item")
                target_item = page.locator(".menu-item-card").first

            # Try Quick Add first, else click card + modal
            quick_add = target_item.locator(".menu-item-card__quick-add")

            # Helper to handle modal
            async def handle_possible_modal():
                # Check if modal is visible/active
                modal = page.locator("#item-modal")
                try:
                    if await modal.is_visible(timeout=3000):
                        print("Item Modal detected. Handling modifiers if any.")

                        # Select first option of each modifier group to ensure required ones are filled
                        # This matches standard radio/checkbox groups
                        modifier_groups = modal.locator(".modifier-group")
                        count = await modifier_groups.count()
                        if count > 0:
                            print(f"Found {count} modifier groups. Selecting first options...")
                            for i in range(count):
                                group = modifier_groups.nth(i)
                                # Click the first input (radio or checkbox)
                                # Use force=True to bypass potential overlap checks
                                await group.locator("input").first.click(force=True)

                        # Try to click add
                        await page.click("#modal-add-to-cart-btn")
                        # Verify close
                        await expect(modal).not_to_be_visible(timeout=3000)
                except Exception as e:
                    # If check fails or modal stays open
                    if await modal.is_visible():
                        print(f"Modal still open after attempt: {e}")
                        # Try closing via close button to fail gracefully?
                        # Or just let it fail
                        pass

            if await quick_add.is_visible():
                await quick_add.click()
                print("Clicked Quick Add")
                await handle_possible_modal()
            else:
                await target_item.click()
                print("Clicked Card")
                await page.wait_for_selector("#item-modal", state="visible")
                await handle_possible_modal()
                # Note: handle_possible_modal does the clicking and waiting

            # Wait for cart notification or badge update
            await page.wait_for_timeout(1000)

            # 2. Open Cart
            # The cart might open auto, or we click the header button
            # Check if cart panel is already open?
            cart_panel = page.locator("#cart-panel")
            is_panel_visible = await cart_panel.is_visible()
            panel_class = await cart_panel.get_attribute("class") or ""

            if not is_panel_visible or "open" not in panel_class:
                cart_btn = page.locator("button[data-toggle-cart], .cart-btn").first
                if await cart_btn.is_visible():
                    await cart_btn.click()
                    await page.wait_for_timeout(500)

            # Verify cart has items
            cart_items = page.locator(".cart-item")
            count = await cart_items.count()
            print(f"Cart items found: {count}")
            if count == 0:
                # Try to debug
                content = await page.content()
                # print(f"Page content dump: {content[:500]}...")
                raise RuntimeError("Cart is empty, cannot proceed to checkout")

            # 3. Proceed to Checkout
            checkout_btn = page.locator("#checkout-btn")
            await checkout_btn.click()
            # SPA transition: wait for checkout section to be visible
            await expect(page.locator("#checkout-section")).to_be_visible(timeout=5000)

            # 4. Fill Checkout Form
            await page.fill("#customer-name", self.data["customer_name"])
            await page.fill("#customer-email", self.data["customer_email"])
            await page.evaluate(
                f"document.getElementById('table-number').value = '{self.data['table_number']}'"
            )

            # Submit
            await page.click("#checkout-submit-btn")

            # 5. Wait for success (SPA transition)

            # 6. Extract Order ID from "Active Orders" card

            # 6. Extract Order ID from "Active Orders" card
            # Look for ".kanban-card__label" text which contains "Orden #123"
            order_label = page.locator(".kanban-card__label").first
            await expect(order_label).to_be_visible(timeout=15000)
            text = await order_label.inner_text()

            # Regex to find "#123"
            match = re.search(r"#(\d+)", text)
            if match:
                self.data["order_id"] = match.group(1)
                self.logger.log_success(f"Order created via UI. ID: {self.data['order_id']}")
            else:
                self.logger.log_error("Order created but ID not found in UI text.")

        except Exception as e:
            await page.screenshot(path=f"error_client_order_{int(time.time())}.png")
            self.logger.log_error(f"Client Step Failed: {e}. URL: {page.url}")
            raise e
        finally:
            await page.close()

    async def step_waiter_accept(self, context: BrowserContext):
        print("\n--- STEP 2: WAITER ACCEPT (UI) ---")
        if not self.data["order_id"]:
            return

        page = await context.new_page()
        page.on(
            "request",
            lambda request: print(
                f">> Request: {request.method} {request.url} DATA: {request.post_data}"
            )
            if request.method == "POST"
            else None,
        )
        try:
            await page.goto(f"{BASE_URL_EMPLOYEE}/waiter/login")
            await page.wait_for_load_state("networkidle")

            # Check if likely already logged in or redirected?
            # But context is fresh.
            debug_btn = page.locator(".debug-btn", has_text="Mesero")
            if await debug_btn.is_visible():
                print("Using debug quick login button for waiter.")
                await debug_btn.click()
                # Wait for values to be filled by JS
                await asyncio.sleep(0.5)
                await page.click("button[type='submit']")
            elif await page.locator("#email").is_visible():
                email, password = "juan.mesero@cafeteria.test", "ChangeMe!123"
                print(f"Logging in waiter manually: {email}")
                await page.fill("#email", email)
                await page.fill("#password", password)
                await page.click("button[type='submit']")
            else:
                print("Already logged in or on dashboard?")

            await page.wait_for_load_state("networkidle")
            await asyncio.sleep(2)
            print(f"URL after login attempt: {page.url}")

            # Wait for dashboard content
            await expect(page.locator("#waiter-orders")).to_be_visible(timeout=30000)
            print("Waiter dashboard visible.")

            # Find row for our order
            oid = self.data["order_id"]
            row_selector = f"tr[data-order-id='{oid}']"
            await page.wait_for_selector(row_selector, timeout=20000)

            # Find Accept button: data-endpoint*="/accept"
            # It might take a moment to appear if polling
            accept_btn = page.locator(f"{row_selector} button[data-endpoint*='/accept']")

            if await accept_btn.count() > 0:
                await accept_btn.click()
                # Wait for button to disappear (status change)
                await expect(accept_btn).to_be_hidden()
                self.logger.log_success(f"Waiter accepted Order #{oid}")
            else:
                # Check if already accepted (status might be queued)
                status = await page.locator(f"{row_selector} .status").inner_text()
                if "Asignada" in status or "Cocinando" in status:
                    self.logger.log_warning(f"Order #{oid} already accepted (Status: {status})")
                else:
                    self.logger.log_error(f"Accept button not found for Order #{oid}")

        except Exception as e:
            await page.screenshot(path=f"error_waiter_accept_{int(time.time())}.png")
            self.logger.log_error(f"Waiter Accept Failed: {e}. URL: {page.url}")
            raise e
        finally:
            await page.close()

    async def step_chef_process(self, context: BrowserContext):
        print("\n--- STEP 3: CHEF PROCESS (UI) ---")
        if not self.data["order_id"]:
            return

        page = await context.new_page()
        try:
            debug_btn = page.locator(".debug-btn", has_text="Chef")
            if await debug_btn.is_visible():
                print("Using debug quick login button for chef.")
                await debug_btn.click()
                await asyncio.sleep(0.5)
                await page.click("button[type='submit']")
            elif await page.locator("#email").is_visible():
                email, password = "carlos.chef@cafeteria.test", "ChangeMe!123"
                print(f"Logging in chef manually: {email}")
                await page.fill("#email", email)
                await page.fill("#password", password)
                await page.click("button[type='submit']")

            await page.wait_for_load_state("networkidle")
            await asyncio.sleep(2)
            print(f"URL after login attempt: {page.url}")

            # Chef board table ID: #kitchen-orders
            await expect(page.locator("#kitchen-orders")).to_be_visible(timeout=30000)
            print("Chef dashboard visible.")

            oid = self.data["order_id"]
            row_selector = f"tr[data-order-id='{oid}']"
            await page.wait_for_selector(row_selector, timeout=20000)

            # 1. Start Preparation (queued -> preparing)
            start_btn = page.locator(f"{row_selector} button[data-endpoint*='/kitchen/start']")
            if await start_btn.count() > 0:
                await start_btn.click()
                await expect(start_btn).to_be_hidden()
                self.logger.log_success(f"Chef started Order #{oid}")
                await page.wait_for_timeout(1000)  # Wait for update

            # 2. Mark Ready (preparing -> ready)
            ready_btn = page.locator(f"{row_selector} button[data-endpoint*='/kitchen/ready']")
            # Might need to wait for poll/refresh
            await expect(ready_btn).to_be_visible(timeout=5000)
            await ready_btn.click()
            await expect(ready_btn).to_be_hidden()
            self.logger.log_success(f"Chef marked Order #{oid} as READY")

        except Exception as e:
            await page.screenshot(path=f"error_chef_process_{int(time.time())}.png")
            self.logger.log_error(f"Chef Process Failed: {e}. URL: {page.url}")
            raise e
        finally:
            await page.close()

    async def step_waiter_deliver(self, context: BrowserContext):
        print("\n--- STEP 4: WAITER DELIVER (UI) ---")
        if not self.data["order_id"]:
            return

        page = await context.new_page()
        try:
            debug_btn = page.locator(".debug-btn", has_text="Mesero")
            if "login" in page.url or await page.locator("#email").is_visible():
                if await debug_btn.is_visible():
                    print("Using debug quick login button for waiter (deliver).")
                    await debug_btn.click()
                    await asyncio.sleep(0.5)
                    await page.click("button[type='submit']")
                else:
                    email, password = "juan.mesero@cafeteria.test", "ChangeMe!123"
                    print(f"Logging in waiter (deliver) manually: {email}")
                    await page.fill("#email", email)
                    await page.fill("#password", password)
                    await page.click("button[type='submit']")

                await page.wait_for_load_state("networkidle")
                await asyncio.sleep(2)
                print(f"URL after login attempt: {page.url}")

            oid = self.data["order_id"]
            row_selector = f"tr[data-order-id='{oid}']"
            await expect(page.locator("#waiter-orders")).to_be_visible(timeout=30000)
            print("Waiter dashboard visible for delivery.")
            await page.wait_for_selector(row_selector, timeout=10000)

            # Deliver button
            deliver_btn = page.locator(f"{row_selector} button[data-endpoint*='/deliver']")
            await expect(deliver_btn).to_be_visible(timeout=5000)
            await deliver_btn.click()
            await expect(deliver_btn).to_be_hidden()
            self.logger.log_success(f"Waiter delivered Order #{oid}")

        except Exception as e:
            await page.screenshot(path=f"error_waiter_deliver_{int(time.time())}.png")
            self.logger.log_error(f"Waiter Deliver Failed: {e}. URL: {page.url}")
            raise e
        finally:
            await page.close()

    async def step_cashier_pay(self, context: BrowserContext):
        print("\n--- STEP 5: CASHIER PAY (UI) ---")
        if not self.data["order_id"]:
            return

        page = await context.new_page()
        try:
            debug_btn = page.locator(".debug-btn", has_text="Cajero")
            if await page.locator("#email").is_visible():
                if await debug_btn.is_visible():
                    print("Using debug quick login button for cashier.")
                    await debug_btn.click()
                    await asyncio.sleep(0.5)
                    await page.click("button[type='submit']")
                else:
                    email, password = "laura.cajera@cafeteria.test", "ChangeMe!123"
                    print(f"Logging in cashier manually: {email}")
                    await page.fill("#email", email)
                    await page.fill("#password", password)
                    await page.click("button[type='submit']")

                await page.wait_for_load_state("networkidle")
                await asyncio.sleep(2)
                print(f"URL after login attempt: {page.url}")

            # Cashier board table ID: #cashier-orders
            await expect(page.locator("#cashier-orders")).to_be_visible(timeout=30000)
            print("Cashier dashboard visible.")

            oid = self.data["order_id"]
            # Cashier board also uses tr[data-order-id]
            row_selector = f"tr[data-order-id='{oid}']"
            await page.wait_for_selector(row_selector, timeout=20000)

            # 1. Click "Cobrar" (Open Payment Modal)
            pay_modal_btn = page.locator(f"{row_selector} button[data-open-payment-modal='true']")
            await expect(pay_modal_btn).to_be_visible(timeout=5000)
            await pay_modal_btn.click()

            # 2. Wait for Modal and Select Cash
            await page.wait_for_selector("#employee-payment-modal.active")

            # Click "Efectivo" method
            cash_method_btn = page.locator("button[data-method='cash']")
            await cash_method_btn.click()

            # 3. Confirm Cash Payment
            confirm_btn = page.locator("#confirm-cash-payment")
            await expect(confirm_btn).to_be_visible()
            await confirm_btn.click()

            # 4. Verify Success (Modal closes or Notification)
            # Expect modal to close or show tip modal
            # Tip modal id: #employee-tip-modal
            # Payment modal should loose .active
            await expect(page.locator("#employee-payment-modal")).not_to_have_class(
                re.compile(r"active"), timeout=5000
            )
            self.logger.log_success(f"Cashier processed payment for Order #{oid}")

        except Exception as e:
            await page.screenshot(path=f"error_cashier_pay_{int(time.time())}.png")
            self.logger.log_error(f"Cashier Pay Failed: {e}. URL: {page.url}")
            raise e
        finally:
            await page.close()


if __name__ == "__main__":
    test = ProntoQATestUI()
    asyncio.run(test.run())
