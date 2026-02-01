#!/usr/bin/env python3
"""Debug script with cache clearing and hard refresh."""

import asyncio
import time

from playwright.async_api import async_playwright


async def debug_button_with_cache_clear():
    async with async_playwright() as p:
        context = await p.chromium.launch_persistent_context("/tmp/pw_cache_clear")
        page = context.pages[0] if context.pages else await context.new_page()

        # Clear all cache
        await page.context.clear_cookies()

        # Navigate with cache bust
        await page.goto(
            "http://localhost:6080?bust=" + str(time.time()), wait_until="domcontentloaded"
        )
        print("✅ Client app loaded (cache busted)")

        # Wait for styles to load
        await page.wait_for_timeout(3000)

        # Get button element
        button = page.locator("button#checkout-submit-btn")
        count = await button.count()
        print(f"Button found: {count > 0}")

        if count > 0:
            print(f"Button visible: {await button.is_visible()}")

            # Get styles more robustly
            styles = await page.evaluate(
                """
                () => {
                    const btn = document.getElementById('checkout-submit-btn');
                    if (!btn) return null;
                    let el = btn;
                    for (let i = 0; i < 10 && el; i++) {
                        const computed = window.getComputedStyle(el);
                        console.log(`[${i}] ${el.tagName}.${el.className} - opacity: ${computed.opacity}`);
                        if (computed.opacity === '0') {
                            return {
                                problem: `Parent [${i}] ${el.tagName}.${el.className} has opacity: 0`,
                                cssRules: this.getCSSRules(el)
                            };
                        }
                        el = el.parentElement;
                    }
                    return {status: 'OK - No opacity: 0 parents found'};
                }
            """
            )

            print(f"Result: {styles}")

        await context.close()


asyncio.run(debug_button_with_cache_clear())
