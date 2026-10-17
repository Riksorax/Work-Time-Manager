import { expect, gotoReady, seedPreferences, test } from './fixtures';

/** Branding (#437): Logo in Sidenav und Login wird geladen, Favicon-/Manifest-Verweise sind erreichbar. */

test.beforeEach(async ({ page }) => {
  await seedPreferences(page, 'de', 'light');
});

async function loaded(img: import('@playwright/test').Locator): Promise<boolean> {
  return img.evaluate((el: HTMLImageElement) => el.complete && el.naturalWidth > 0);
}

test('Sidenav zeigt das Logo als geladenes, dekoratives Bild', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await gotoReady(page, '/dashboard');
  const logo = page.locator('.sidenav-header img.sidenav-logo');
  await expect(logo).toBeVisible();
  await expect(logo).toHaveAttribute('alt', '');
  expect(await loaded(logo)).toBe(true);
  await expect(page.locator('.sidenav-header mat-icon')).toHaveCount(0);
});

test('Login zeigt das Logo als geladenes, dekoratives Bild', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 700 });
  await gotoReady(page, '/auth/login');
  const logo = page.locator('.logo-wrapper img.logo-icon');
  await expect(logo).toBeVisible();
  await expect(logo).toHaveAttribute('alt', '');
  expect(await loaded(logo)).toBe(true);
});

test('index.html: favicon.svg steht zuerst, alle Icon-Verweise und das Manifest sind erreichbar', async ({ page, request }) => {
  await gotoReady(page, '/dashboard');
  const hrefs = await page.locator('link[rel~="icon"], link[rel="apple-touch-icon"], link[rel="manifest"]')
    .evaluateAll(els => els.map(e => (e as HTMLLinkElement).href));
  const firstIcon = await page.locator('link[rel="icon"]').first().getAttribute('href');
  expect(firstIcon).toContain('favicon.svg');
  for (const href of hrefs) {
    expect(href, href).toContain('?v=170');
    const res = await request.get(href);
    expect(res.status(), href).toBe(200);
  }
  const manifestHref = hrefs.find(h => h.includes('manifest.json'))!;
  const manifest = await (await request.get(manifestHref)).json();
  for (const icon of manifest.icons) {
    const res = await request.get(new URL(icon.src, manifestHref).href);
    expect(res.status(), icon.src).toBe(200);
  }
});
