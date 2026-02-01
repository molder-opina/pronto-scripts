#!/usr/bin/env python3
"""Check button dimensions and position."""

import asyncio

from playwright.async_api import async_playwright


async def check_button_layout():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        page = await browser.new_page()

        await page.goto("http://localhost:6080", wait_until="networkidle")
        await page.wait_for_timeout(3000)

        # Get button info
        info = await page.evaluate(
            """
            () => {
                const btn = document.querySelector('button#checkout-submit-btn');
                if (!btn) return {error: 'Button not found'};
                const rect = btn.getBoundingClientRect();
                const computed = window.getComputedStyle(btn);
                return {
                    'button-text': btn.textContent.trim(),
                    'display': computed.display,
                    'visibility': computed.visibility,
                    'opacity': computed.opacity,
                    'position': computed.position,
                    'width': rect.width,
                    'height': rect.height,
                    'top': rect.top,
                    'left': rect.left,
                    'in-viewport': rect.top >= 0 && rect.left >= 0 && rect.top < window.innerHeight,
                    'parent-display': window.getComputedStyle(btn.parentElement).display,
                    'parent-opacity': window.getComputedStyle(btn.parentElement).opacity,
                };
            }
        """
        )

        print("📍 Button Layout Info:")
        for key, value in info.items():
            print(f"  {key}: {value}")

        await browser.close()


asyncio.run(check_button_layout())
