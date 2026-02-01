#!/usr/bin/env python3
"""Check inline styles on accordion-content."""
import asyncio

from playwright.async_api import async_playwright


async def check_inline_styles():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        page = await browser.new_page()

        await page.goto("http://localhost:6080", wait_until="networkidle")
        await page.wait_for_timeout(2000)

        # Get inline style
        inline_style = await page.evaluate(
            """
            () => {
                const elem = document.querySelector('.accordion-content');
                if (!elem) return {error: 'Element not found'};
                return {
                    'inline-style': elem.getAttribute('style') || 'NONE',
                    'computed-opacity': window.getComputedStyle(elem).opacity,
                    'all-classes': elem.className,
                };
            }
        """
        )

        print(f"Inline styles info: {inline_style}")

        await browser.close()


asyncio.run(check_inline_styles())
