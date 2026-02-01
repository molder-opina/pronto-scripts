#!/usr/bin/env python3
"""Aggressive debugging - check what's happening with the fixes."""
import asyncio

from playwright.async_api import async_playwright


async def debug():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        page = await browser.new_page()

        await page.goto("http://localhost:6080", wait_until="networkidle")
        await page.wait_for_timeout(3000)

        # Check if style tag is present
        style_present = await page.evaluate(
            """
            () => {
                const styleTag = document.querySelector('#qa-error-fixes-final');
                return {
                    'style-tag-present': !!styleTag,
                    'style-tag-content': styleTag ? styleTag.textContent.substring(0, 200) : 'N/A',
                    'accordion-count': document.querySelectorAll('.accordion-content').length,
                    'first-accordion-opacity': document.querySelectorAll('.accordion-content')[0] ?
                        window.getComputedStyle(document.querySelectorAll('.accordion-content')[0]).opacity : 'N/A',
                };
            }
        """
        )

        print(f"📋 Page Analysis: {style_present}")

        # Check if JS fix ran
        js_fix_ran = await page.evaluate(
            """
            () => {
                // Try to manually run the fix
                const elements = document.querySelectorAll('.accordion-content');
                elements.forEach(el => {
                    el.style.setProperty('opacity', '1', 'important');
                    el.style.setProperty('visibility', 'visible', 'important');
                });

                const firstEl = elements[0];
                if (firstEl) {
                    return {
                        'after-js-fix-opacity': window.getComputedStyle(firstEl).opacity,
                        'after-js-fix-inline-opacity': firstEl.style.opacity || 'NOT SET',
                    };
                }
                return {error: 'No accordion found'};
            }
        """
        )

        print(f"🔧 After JS Fix: {js_fix_ran}")

        # Check button now
        is_visible = (
            await page.locator("button#checkout-submit-btn")
            .is_visible(timeout=500)
            .catch(lambda: False)
        )
        print(f"✅ Button visible after JS fix: {is_visible}")

        await browser.close()


asyncio.run(debug())
