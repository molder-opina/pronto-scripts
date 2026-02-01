#!/usr/bin/env python3
"""Debug script to check checkout button visibility in detail."""
import asyncio

from playwright.async_api import async_playwright


async def debug_checkout_button():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        page = await browser.new_page()

        # Navigate to client app
        await page.goto("http://localhost:6080", wait_until="networkidle")
        print("✅ Client app loaded")

        # Wait for menu to load
        await page.wait_for_load_state("networkidle")
        await page.wait_for_timeout(2000)

        # Get button element
        button = page.locator("button#checkout-submit-btn")

        # Check if button exists
        count = await button.count()
        print(f"Button count: {count}")

        if count > 0:
            # Get detailed info
            print(f"Button visible: {await button.is_visible()}")
            print(f"Button enabled: {await button.is_enabled()}")

            # Get computed styles
            styles = await page.evaluate(
                """
                () => {
                    const btn = document.getElementById('checkout-submit-btn');
                    if (!btn) return {error: 'Button not found'};
                    const computed = window.getComputedStyle(btn);
                    return {
                        display: computed.display,
                        visibility: computed.visibility,
                        opacity: computed.opacity,
                        pointerEvents: computed.pointerEvents,
                        zIndex: computed.zIndex,
                        width: computed.width,
                        height: computed.height,
                        position: computed.position,
                        top: computed.top,
                        left: computed.left,
                        'parent-display': window.getComputedStyle(btn.parentElement).display,
                        'parent-visibility': window.getComputedStyle(btn.parentElement).visibility,
                        'parent-zIndex': window.getComputedStyle(btn.parentElement).zIndex,
                    };
                }
            """
            )

            print("\n📊 Button Computed Styles:")
            for key, value in styles.items():
                print(f"  {key}: {value}")

            # Check parent chain
            parent_info = await page.evaluate(
                """
                () => {
                    const btn = document.getElementById('checkout-submit-btn');
                    const parents = [];
                    let el = btn;
                    for (let i = 0; i < 10 && el; i++) {
                        const computed = window.getComputedStyle(el);
                        parents.push({
                            tag: el.tagName,
                            class: el.className,
                            display: computed.display,
                            visibility: computed.visibility,
                            opacity: computed.opacity,
                            zIndex: computed.zIndex,
                        });
                        el = el.parentElement;
                    }
                    return parents;
                }
            """
            )

            print("\n🔗 Parent Chain:")
            for i, parent in enumerate(parent_info):
                print(
                    f"  [{i}] {parent['tag']}.{parent['class']} - display: {parent['display']}, visibility: {parent['visibility']}, opacity: {parent['opacity']}, z-index: {parent['zIndex']}"
                )
        else:
            print("❌ Button not found in DOM")

        await browser.close()


asyncio.run(debug_checkout_button())
