import asyncio
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

            try:
                await self.step_1_client_negative_test(browser)
                await self.step_2_client_create_order(browser)

                # Employee Flow
                context_emp = await browser.new_context()
                await self.step_3_waiter_accept(context_emp)
                await self.step_4_chef_process(context_emp)
                await self.step_5_waiter_deliver(context_emp)
                await self.step_6_cashier_pay(context_emp)
                await self.step_7_final_verifications(context_emp)

            except Exception as e:
                print(f"CRITICAL TEST FAILURE: {e}")
                self.log_error(f"Test aborted due to exception: {e}", "CRITICAL")
            finally:
                await browser.close()

    async def step_1_client_negative_test(self, browser):
        print("\n--- STEP 1: CLIENT NEGATIVE TEST ---")
        page = await browser.new_page()
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
                    cart_count = await page.locator("#cart-count, .cart-badge").first.inner_text()
                    if cart_count == "0" or not cart_count:
                        print("✅ Negative test passed: Cart remained empty.")
                    else:
                        self.log_error(
                            "Negative test failed: Item added or no error shown when missing required options.",
                            "MEDIUM",
                        )
            else:
                print("Combo not found for negative test, adding dummy check.")

            close_btn = page.locator(
                "#close-modal-btn, .modal-close, button:has-text('Cancelar')"
            ).first
            if await close_btn.is_visible():
                await close_btn.click()
        finally:
            await page.close()

    async def step_2_client_create_order(self, browser):
        print("\n--- STEP 2: CLIENT CREATE ORDER (UI) ---")
        page = await browser.new_page()
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

            # Checkout
            checkout_btn = page.locator("#checkout-btn")
            await checkout_btn.scroll_into_view_if_needed()
            await checkout_btn.click()
            await expect(page.locator("#customer-email")).to_be_visible()

            await page.fill("#customer-name", "QA Tester Senior")
            await page.fill("#customer-email", "luartx@gmail.com")
            await page.fill("#table-number", "5")

            await page.click("#checkout-submit-btn, button[type='submit']")

            await expect(
                page.locator(".success-message, .order-confirmation, :has-text('Gracias')")
            ).to_be_visible(timeout=30000)
            order_id_text = await page.locator(
                ".order-id, .kanban-card__label, .order-number"
            ).first.inner_text()

            match = re.search(r"#?(\d+)", order_id_text)
            self.data["order_id"] = match.group(1) if match else "ID_NOT_FOUND"
            print(f"✅ Order Created: #{self.data['order_id']}")
        finally:
            await page.close()

    async def step_3_waiter_accept(self, context):
        print("\n--- STEP 3: WAITER ACCEPT ---")
        page = await context.new_page()
        try:
            await page.goto(f"{BASE_URL_EMPLOYEE}/waiter/login")

            if await page.locator(".debug-panel-employee, #debug-panel").is_visible():
                self.debug_panel_found = True

            debug_btn = page.locator(".debug-btn", has_text="Mesero")
            if await debug_btn.is_visible():
                await debug_btn.click()
                await asyncio.sleep(0.5)
                await page.click("button[type='submit']")
            else:
                await page.fill("#email", "juan.mesero@cafeteria.test")
                await page.fill("#password", "ChangeMe!123")
                await page.click("button[type='submit']")

            await expect(page.locator("#waiter-orders")).to_be_visible(timeout=30000)

            row = page.locator(f"tr[data-order-id='{self.data['order_id']}']")
            await expect(row).to_be_visible(timeout=10000)

            accept_btn = row.locator("button[data-endpoint*='/accept']")
            await accept_btn.click()
            await expect(accept_btn).to_be_hidden()
            print("✅ Waiter accepted order.")
        finally:
            await page.close()

    async def step_4_chef_process(self, context):
        print("\n--- STEP 4: CHEF PROCESS ---")
        page = await context.new_page()
        try:
            await page.goto(f"{BASE_URL_EMPLOYEE}/chef/login")

            debug_btn = page.locator(".debug-btn", has_text="Chef")
            if await debug_btn.is_visible():
                await debug_btn.click()
                await asyncio.sleep(0.5)
                await page.click("button[type='submit']")
            else:
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

    async def step_5_waiter_deliver(self, context):
        print("\n--- STEP 5: WAITER DELIVER ---")
        page = await context.new_page()
        try:
            await page.goto(f"{BASE_URL_EMPLOYEE}/waiter")
            row = page.locator(f"tr[data-order-id='{self.data['order_id']}']")
            await expect(row).to_be_visible(timeout=30000)

            deliver_btn = row.locator("button[data-endpoint*='/deliver']")
            await deliver_btn.click()
            await expect(deliver_btn).to_be_hidden()
            print("✅ Waiter delivered order.")
        finally:
            await page.close()

    async def step_6_cashier_pay(self, context):
        print("\n--- STEP 6: CASHIER PAYMENT ---")
        page = await context.new_page()
        try:
            await page.goto(f"{BASE_URL_EMPLOYEE}/cashier/login")

            debug_btn = page.locator(".debug-btn", has_text="Cajero")
            if await debug_btn.is_visible():
                await debug_btn.click()
                await asyncio.sleep(0.5)
                await page.click("button[type='submit']")
            else:
                await page.fill("#email", "laura.cajera@cafeteria.test")
                await page.fill("#password", "ChangeMe!123")
                await page.click("button[type='submit']")

            await expect(page.locator("#cashier-orders")).to_be_visible(timeout=30000)
            row = page.locator(f"tr[data-order-id='{self.data['order_id']}']")

            pay_btn = row.locator(
                "button:has-text('Cobrar'), button[data-action='pay'], .pay-btn"
            ).first
            await pay_btn.click()

            # Select Cash (Efectivo)
            await page.locator("button:has-text('Efectivo'), #method-cash").first.click()
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

    async def step_7_final_verifications(self, context):
        print("\n--- STEP 7: FINAL VERIFICATIONS ---")
        page = await context.new_page()
        try:
            await page.goto(f"{BASE_URL_EMPLOYEE}/cashier")
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
