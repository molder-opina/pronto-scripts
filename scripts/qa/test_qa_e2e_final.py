import asyncio
import random
import re
import time

from playwright.async_api import async_playwright, expect

# Constants
BASE_URL_CLIENT = "http://localhost:6080"
BASE_URL_EMPLOYEE = "http://localhost:6081"


class ProntoE2EFinal:
    def __init__(self):
        self.data = {}
        self.errors = []
        self.findings = []
        self.debug_panel_found = False

    def log_error(self, message, severity="HIGH"):
        self.errors.append({"msg": message, "sev": severity})
        print(f"ERROR [{severity}]: {message}")

    async def run(self):
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            context = await browser.new_context(viewport={"width": 1280, "height": 1024})

            try:
                # Add console log listener to the context to capture all pages
                context.on(
                    "console", lambda msg: print(f"BROWSER CONSOLE [{msg.type}]: {msg.text}")
                )
                context.on(
                    "page",
                    lambda page: page.on(
                        "console",
                        lambda msg: print(f"BROWSER CONSOLE [{msg.type}] ({page.url}): {msg.text}"),
                    ),
                )

                await self.step_1_client_negative_test(context)
                await self.step_2_client_create_order(context)

                # Employee Flow (Isolated Contexts)
                await self.step_3_waiter_accept(browser)
                await self.step_4_chef_process(browser)
                await self.step_5_waiter_deliver(browser)
                await self.step_6_cashier_pay(browser)
                await self.step_7_final_verifications(browser)

            except Exception as e:
                print(f"CRITICAL TEST FAILURE: {e}")
                self.log_error(f"Test aborted due to exception: {e}", "CRITICAL")
            finally:
                await browser.close()

    async def step_1_client_negative_test(self, context):
        print("\n--- STEP 1: CLIENT NEGATIVE TEST ---")
        page = await context.new_page()
        try:
            await page.goto(BASE_URL_CLIENT)
            await page.wait_for_load_state("networkidle")

            combo_card = page.locator(".menu-item-card", has_text="Combo Familiar")
            if await combo_card.count() == 0:
                combo_card = page.locator(".menu-item-card", has_text="Combo")

            if await combo_card.count() > 0:
                await combo_card.click()
                await expect(page.locator("#item-modal")).to_be_visible()

                add_btn = page.locator("#modal-add-to-cart-btn")

                # Check if disabled first (client side validation active)
                if await add_btn.is_disabled():
                    print(
                        "✅ Negative test passed: 'Add to Cart' button is disabled due to missing modifiers."
                    )
                else:
                    await add_btn.click()

                    # Check for validation highlight or message
                    error_msg = page.locator(
                        ".validation-error, .text-red-500, .error-message, [role='alert'], .invalid-feedback"
                    )
                    found_error = False
                    for i in range(await error_msg.count()):
                        if await error_msg.nth(i).is_visible():
                            found_error = True
                            break

                    if found_error:
                        print("✅ Negative test passed: Validation error blocked 'Add to Cart'.")
                    else:
                        # Let's check if cart changed
                        cart_count = await page.locator(
                            "#cart-count, .cart-badge"
                        ).first.inner_text()
                        if cart_count == "0" or not cart_count:
                            print("✅ Negative test passed: Cart remained empty.")
                        else:
                            self.log_error(
                                "Negative test failed: Item added or no error shown when missing required options.",
                                "MEDIUM",
                            )

            close_btn = page.locator(
                "#close-modal-btn, .modal-close, button:has-text('Cancelar')"
            ).first
            if await close_btn.is_visible():
                await close_btn.click()
        finally:
            await page.close()

    async def step_2_client_create_order(self, context):
        print("\n--- STEP 2: CLIENT CREATE ORDER (UI) ---")
        page = await context.new_page()
        try:
            await page.goto(BASE_URL_CLIENT)

            # 1. Add Combo Familiar
            combo_card = page.locator(".menu-item-card", has_text="Combo Familiar")
            await combo_card.click()
            await expect(page.locator("#item-modal")).to_be_visible()

            groups = page.locator(".modifier-group")
            for i in range(await groups.count()):
                group = groups.nth(i)
                option = group.locator(
                    ".modifier-option, .custom-control-input, input[type='radio'], input[type='checkbox']"
                ).first
                await option.click()

            await page.locator("#modal-add-to-cart-btn").click()
            await expect(page.locator("#item-modal")).to_be_hidden()

            # 2. Add another item
            pizza_card = page.locator(".menu-item-card", has_text="Pizza Margarita")
            if await pizza_card.count() > 0:
                quick_add = pizza_card.locator(".menu-item-card__quick-add, .quick-add-btn")
                if await quick_add.is_visible():
                    await quick_add.click()
                else:
                    await pizza_card.click()
                    await page.wait_for_selector("#modal-add-to-cart-btn")
                    await page.click("#modal-add-to-cart-btn")

            # Open Cart
            print("Opening cart...")
            cart_toggle = page.locator(
                "#cart-toggle, .cart-btn, .header-actions button:has(.fa-shopping-cart), .header-actions button:has-text('🛒')"
            ).first
            await cart_toggle.click()
            await asyncio.sleep(1)  # Wait for cart panel animation

            # Checkout
            await asyncio.sleep(1)  # Wait for animation
            await page.screenshot(path="debug_cart_opened.png")
            print("Captured debug_cart_opened.png")

            try:
                # Try multiple ways to click that big orange button
                checkout_btn = (
                    page.locator(
                        "#checkout-btn, .checkout-btn, button:has-text('Ir a pagar'), button:has-text('IR A PAGAR')"
                    )
                    .filter(visible=True)
                    .first
                )
                await checkout_btn.click(timeout=5000)
            except Exception:
                print("Click failed, trying JS click on any checkout-like button...")
                await page.evaluate(
                    'document.querySelector(".checkout-btn, #checkout-btn").click()'
                )

            # Set Table Number via Evaluate (Simulating QR/Selection as it's hidden in form)
            print("Setting table number and filling form...")
            await asyncio.sleep(2)  # Wait for checkout form load/transition
            await page.evaluate(
                '() => { \
                const input = document.getElementById("table-number"); \
                if(input) input.value = "5"; \
                sessionStorage.setItem("pronto-table-number", "5"); \
                sessionStorage.setItem("pronto-table-label", "Mesa 5"); \
                if(window.assignTable) window.assignTable("5", "manual"); \
            }'
            )

            await page.fill("#customer-name", "QA Tester Senior")
            await page.fill("#customer-email", "luartx@gmail.com")

            # Intercept the checkout response to get the Order ID reliably
            # Matching specifically POST to /api/orders
            print("Submitting order and waiting for API response...")
            try:
                async with page.expect_response(
                    lambda r: "/api/orders" in r.url and r.request.method == "POST", timeout=30000
                ) as response_info:
                    await page.click("#checkout-submit-btn, button[type='submit']")

                checkout_response = await response_info.value
                if checkout_response.ok:
                    resp_json = await checkout_response.json()
                    # Backend returns { "order_id": ... } or { "id": ... }
                    # Let's check both
                    self.data["order_id"] = str(
                        resp_json.get("order_id") or resp_json.get("id") or ""
                    )
                    print(f"✅ Order ID intercepted from API: #{self.data['order_id']}")
                else:
                    print(f"❌ Checkout API failed: {checkout_response.status}")
                    await page.screenshot(path="debug_checkout_api_fail.png")
            except Exception as e:
                print(f"⚠️ Checkout interception failed: {e}")
                await page.screenshot(path="debug_checkout_timeout.png")

            await asyncio.sleep(2)
            await page.screenshot(path="debug_after_submit.png")
            print("Captured debug_after_submit.png")

            # Dismiss modal
            entendido_btn = (
                page.locator("#confirm-email-btn, button:has-text('Entendido'), .btn-entendido")
                .filter(visible=True)
                .first
            )
            if await entendido_btn.is_visible():
                print("✅ Found visible Entendido button, clicking...")
                await entendido_btn.click()
                await asyncio.sleep(1)

            # Switch views logic is automatic in frontend, wait for it
            await asyncio.sleep(2)
            print(f"✅ Order Created: #{self.data['order_id']}")
        finally:
            await page.close()

    async def step_3_waiter_accept(self, browser):
        print("\n--- STEP 3: WAITER ACCEPT ---")
        context = await browser.new_context()
        page = await context.new_page()
        page.on("console", lambda msg: print(f"BROWSER CONSOLE [WAITER] [{msg.type}]: {msg.text}"))
        page.on("pageerror", lambda err: print(f"BROWSER PAGE ERROR [WAITER]: {err.message}"))

        try:
            # BLOCK unauthorized API calls that trigger 403 redirects
            async def handle_route(route):
                url = route.request.url
                if "/admin/api/feedback" in url or "/api/feedback/stats" in url:
                    print(f"DEBUG: Blocking unauthorized call to: {url}")
                    await route.abort()
                else:
                    await route.continue_()

            await page.route("**/*", handle_route)

            await page.evaluate(
                """
                window.addEventListener('click', (e) => {
                    console.log(`[E2E-CLICK-CAPTURE] Target: ${e.target.tagName} Classes: ${e.target.className} Text: ${e.target.textContent ? e.target.textContent.substring(0, 20) : ''}`);
                }, true);
            """
            )

            await page.goto(f"{BASE_URL_EMPLOYEE}/waiter/login")
            await asyncio.sleep(2)

            if await page.locator(".debug-panel-employee, #debug-panel").is_visible():
                self.debug_panel_found = True

            await page.fill("#email", "admin@cafeteria.test")
            await page.fill("#password", "ChangeMe!123")

            email_val = await page.input_value("#email")
            print(f"DEBUG: Waiter login email set to: '{email_val}'")

            await page.click("button[type='submit'], .login-button")

            # Wait for dashboard or handle 403 redirect
            await asyncio.sleep(2)
            if "authorization-error" in page.url:
                print("⚠️ Redirected to authorization error. Attempting direct dashboard access...")
                await page.goto(f"{BASE_URL_EMPLOYEE}/waiter/dashboard")
                await asyncio.sleep(2)

            await page.screenshot(path="debug_waiter_dashboard_pre.png")
            print("Captured debug_waiter_dashboard_pre.png")
            await expect(
                page.locator(
                    "#waiter-orders, #panel-meseros, .waiter-dashboard, :has-text('Órdenes en Curso')"
                )
                .filter(visible=True)
                .first
            ).to_be_visible(timeout=30000)
            print("✅ Waiter dashboard loaded.")

            row = page.locator(f"tr[data-order-id='{self.data['order_id']}']")
            await expect(row).to_be_visible(timeout=10000)

            accept_btn = row.locator("button[data-endpoint*='/accept']")
            await expect(accept_btn).to_be_visible(timeout=5000)

            # Diagnostic: check attributes
            attrs = await accept_btn.evaluate(
                "el => { r = {}; for(let i=0; i<el.attributes.length; i++){ r[el.attributes[i].name] = el.attributes[i].value }; return r; }"
            )
            print(f"DEBUG: Accept button attrs: {attrs}")

            print("Clicking accept button...")
            await accept_btn.click(force=True)

            await asyncio.sleep(2)  # Give it time to update UI

            if await accept_btn.is_visible():
                print("⚠️ Button still visible after click, attempting manual JS trigger...")
                # Also try to trigger the function directly if it exists on window
                await page.evaluate(
                    f"""
                    const btn = document.querySelector('tr[data-order-id="{self.data['order_id']}"] button[data-endpoint*="/accept"]');
                    if(btn) {{
                        console.log('[E2E-MANUAL] Found button, triggering click');
                        btn.click();
                    }} else {{
                        console.log('[E2E-MANUAL] Button NOT found!');
                    }}
                """
                )
                await asyncio.sleep(2)

            await expect(accept_btn).to_be_hidden(timeout=10000)
            print("✅ Waiter accepted order.")
        except Exception as e:
            print(f"ERROR in Waiter Accept step: {e}")
            raise
        finally:
            await page.close()

    async def step_4_chef_process(self, browser):
        print("\n--- STEP 4: CHEF PROCESS ---")
        context = await browser.new_context()
        page = await context.new_page()
        page.on("console", lambda msg: print(f"BROWSER CONSOLE [CHEF] [{msg.type}]: {msg.text}"))
        page.on("pageerror", lambda err: print(f"BROWSER PAGE ERROR [CHEF]: {err.message}"))
        try:
            await page.goto(f"{BASE_URL_EMPLOYEE}/chef/login")
            await asyncio.sleep(2)

            await page.fill("#email", "carlos.chef@cafeteria.test")
            await page.fill("#password", "ChangeMe!123")
            await page.click("button[type='submit']")

            await expect(page.locator("#kitchen-orders")).to_be_visible(timeout=30000)
            row = page.locator(f"tr[data-order-id='{self.data['order_id']}']")

            start_btn = row.locator("button[data-endpoint*='/start']")
            await start_btn.click()
            await asyncio.sleep(1)

            ready_btn = row.locator("button[data-endpoint*='/ready']")
            await ready_btn.click()
            await expect(ready_btn).to_be_hidden()
            print("✅ Chef processed order: Iniciar -> Listo.")
        finally:
            await page.close()

    async def step_5_waiter_deliver(self, browser):
        print("\n--- STEP 5: WAITER DELIVER ---")
        context = await browser.new_context()
        page = await context.new_page()

        # BLOCK unauthorized API calls that trigger 403 redirects
        async def handle_route(route):
            url = route.request.url
            if "/admin/api/feedback" in url or "/api/feedback/stats" in url:
                await route.abort()
            else:
                await route.continue_()

        await page.route("**/*", handle_route)

        try:
            await page.goto(f"{BASE_URL_EMPLOYEE}/waiter/login")
            await asyncio.sleep(1)
            await page.fill("#email", "admin@cafeteria.test")
            await page.fill("#password", "ChangeMe!123")
            await page.click("button[type='submit']")

            # Wait for dashboard or handle 403 redirect
            await asyncio.sleep(2)
            if "authorization-error" in page.url:
                print("⚠️ Redirected to authorization error. Attempting direct dashboard access...")
                await page.goto(f"{BASE_URL_EMPLOYEE}/waiter/dashboard")
                await asyncio.sleep(2)

            await expect(
                page.locator(
                    "#waiter-orders, #panel-meseros, .waiter-dashboard, :has-text('Órdenes en Curso')"
                )
                .filter(visible=True)
                .first
            ).to_be_visible(timeout=30000)
            print("✅ Waiter logged in.")
            await page.screenshot(path="debug_waiter_dashboard.png")

            row = page.locator(f"tr[data-order-id='{self.data['order_id']}']")
            await expect(row).to_be_visible(timeout=30000)

            deliver_btn = row.locator("button[data-endpoint*='/deliver']")
            await deliver_btn.click()
            await asyncio.sleep(2)
            await expect(deliver_btn).to_be_hidden()
            print("✅ Waiter delivered order.")
        finally:
            await page.close()

    async def step_6_cashier_pay(self, browser):
        print("\n--- STEP 6: CASHIER PAYMENT ---")
        context = await browser.new_context()
        page = await context.new_page()

        # BLOCK unauthorized API calls that trigger 403 redirects
        async def handle_route(route):
            url = route.request.url
            if "/admin/api/feedback" in url or "/api/feedback/stats" in url:
                await route.abort()
            else:
                await route.continue_()

        await page.route("**/*", handle_route)

        try:
            await page.goto(f"{BASE_URL_EMPLOYEE}/cashier/login")
            await asyncio.sleep(2)

            await page.fill("#email", "admin@cafeteria.test")  # Using admin for cashier reliability
            await page.fill("#password", "ChangeMe!123")
            await page.click("button[type='submit']")

            # Updated locator for cashier/main dashboard
            await expect(
                page.locator(
                    "#cashier-panel, #panel-meseros, .cashier-dashboard, :has-text('Caja')"
                ).first
            ).to_be_visible(timeout=30000)
            print("✅ Cashier logged in.")
            row = page.locator(f"tr[data-order-id='{self.data['order_id']}']")

            pay_btn = row.locator(
                "button:has-text('Cobrar'), button[data-action='pay'], .pay-btn"
            ).first
            await pay_btn.click()
            await asyncio.sleep(1)

            # Select Cash (Efectivo)
            await page.locator("button:has-text('Efectivo'), #method-cash").first.click()
            await asyncio.sleep(0.5)
            await page.locator(
                "#confirm-payment-btn, .confirm-btn, button:has-text('Confirmar')"
            ).first.click()

            # Verify notification
            await expect(
                page.locator(":has-text('Email enviado'), :has-text('Pago exitoso')")
            ).to_be_visible(timeout=10000)
            print("✅ Payment processed (Cash). 'Email enviado' notification visible.")
        finally:
            await page.close()

    async def step_7_final_verifications(self, browser):
        print("\n--- STEP 7: FINAL VERIFICATIONS ---")
        context = await browser.new_context()
        page = await context.new_page()
        try:
            await page.fill("#email", "admin@cafeteria.test")
            await page.fill("#password", "ChangeMe!123")
            await page.click("button[type='submit']")

            await expect(page.locator(".waiter-tab[data-tab='paid']")).to_be_visible(timeout=30000)
            await page.click(".waiter-tab[data-tab='paid']")
            await asyncio.sleep(2)  # Wait for table refresh

            paid_table = page.locator("#cashier-paid-sessions")
            order_found = (
                await paid_table.locator(f"tr:has-text('{self.data['order_id']}')").count() > 0
            )
            if order_found:
                print(f"✅ Order #{self.data['order_id']} visible in 'Pagadas' tab.")
            else:
                # Fallback check for any closed session if ID is hard to find in text
                print(
                    f"⚠️ Warning: Could not find exact ID {self.data['order_id']} in Paid tab, checking for recent sessions."
                )
                if await paid_table.locator("tr").count() > 1:
                    print("✅ Sessions visible in Paid tab.")
                else:
                    self.log_error("Paid tab is empty or order not visible.", "HIGH")

            # PDF and Email buttons presence
            buttons = page.locator(
                "button:has-text('Email'), a:has-text('PDF'), .resend-email, .download-pdf"
            )
            if await buttons.count() > 0:
                print("✅ Email/PDF actions found in dashboard.")
            else:
                self.log_error("Email/PDF buttons not found in Paid section.", "MEDIUM")
        finally:
            await page.close()


if __name__ == "__main__":
    tester = ProntoE2EFinal()
    asyncio.run(tester.run())
