#!/usr/bin/env python3
"""Simple debug - check if button is now visible."""
import asyncio

from playwright.async_api import async_playwright


async def test_button():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        await page.goto("http://localhost:6080", wait_until="networkidle")
        await page.wait_for_timeout(2000)

        # Check if button is visible
        try:
            button = page.locator("button#checkout-submit-btn, button:has-text('Confirmar Pedido')")
            is_visible = await button.is_visible(timeout=1000)
            print(f"✅ Button is NOW VISIBLE: {is_visible}")
        except Exception as e:
            print(f"❌ Error checking button: {e}")

        await browser.close()


asyncio.run(test_button())
