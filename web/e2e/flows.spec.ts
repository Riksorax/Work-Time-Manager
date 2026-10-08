import { expect, gotoReady, seedPreferences, test } from './fixtures';

test.describe('Dashboard', () => {
  test('Timer starten, Pause starten/beenden und Timer beenden', async ({ page }) => {
    await seedPreferences(page, 'de', 'light');
    await gotoReady(page, '/dashboard');

    await page.getByRole('button', { name: 'Zeiterfassung starten' }).click();
    await expect(page.getByRole('button', { name: 'Zeiterfassung beenden' })).toBeVisible();

    await page.getByRole('button', { name: 'Pause starten' }).click();
    await expect(page.getByRole('button', { name: 'Pause beenden' })).toBeVisible();
    await page.getByRole('button', { name: 'Pause beenden' }).click();
    await expect(page.getByRole('button', { name: 'Pause starten' })).toBeVisible();

    await page.getByRole('button', { name: 'Zeiterfassung beenden' }).click();
    await expect(page.getByRole('button', { name: 'Zeiterfassung starten' })).toBeVisible();
  });

  test('laufender Timer übersteht ein Neuladen', async ({ page }) => {
    await seedPreferences(page, 'en', 'light');
    await gotoReady(page, '/dashboard');
    await page.getByRole('button', { name: 'Start time tracking' }).click();
    await page.reload();
    await expect(page.getByRole('button', { name: 'Stop time tracking' })).toBeVisible();
  });
});

test.describe('Resturlaub', () => {
  test('steht nicht im Dashboard, aber in Einstellungen und Reports', async ({ page }) => {
    await seedPreferences(page, 'de', 'light');
    await gotoReady(page, '/dashboard');
    await expect(page.getByRole('button', { name: 'Zeiterfassung starten' })).toBeVisible();
    await expect(page.locator('app-leave-balance-card')).toHaveCount(0);

    await gotoReady(page, '/settings');
    await expect(page.locator('app-leave-balance-card')).toBeVisible();
    await gotoReady(page, '/reports');
    await page.getByRole('tab', { name: 'Jahr', exact: true }).click();
    await expect(page.locator('app-leave-balance-card')).toBeVisible();
  });

  test('Start-Button liegt auf dem Handy ohne Scrollen über der unteren Navigation', async ({ page }) => {
    // 375x812: übliche Handy-Größe. In der Android-Emulation (mobile-chrome) liegt der Button ~85 px tiefer als in
    // Desktop-Chromium (Text-Skalierung), bei 667 px Höhe verdeckt ihn dort die Navigation, daher nicht 667.
    // Mit der Resturlaub-Karte lag er bei 893 (Chromium) bzw. 977 px (mobile-chrome), also unter jedem Handy-Bildschirm.
    await page.setViewportSize({ width: 375, height: 812 });
    await seedPreferences(page, 'de', 'light');
    await gotoReady(page, '/dashboard');
    const button = await page.getByRole('button', { name: 'Zeiterfassung starten' }).boundingBox();
    const nav = await page.locator('nav.bottom-nav').boundingBox();
    expect(button!.y + button!.height).toBeLessThanOrEqual(nav!.y);
  });
});

test.describe('Navigation', () => {
  test('wechselt zwischen Dashboard, Reports und Einstellungen', async ({ page, isMobile }) => {
    await seedPreferences(page, 'en', 'light');
    await gotoReady(page, '/dashboard');
    const nav = isMobile ? page.getByRole('navigation', { name: 'Hauptnavigation' }) : page.getByRole('navigation');

    await nav.getByRole('link', { name: 'Reports' }).click();
    await expect(page).toHaveURL(/\/reports$/);
    await nav.getByRole('link', { name: 'Settings' }).click();
    await expect(page).toHaveURL(/\/settings$/);
    await nav.getByRole('link', { name: 'Dashboard' }).click();
    await expect(page).toHaveURL(/\/dashboard$/);
  });
});

test.describe('Einstellungen', () => {
  test('Theme-Schalter wechselt Hell/Dunkel und merkt es sich', async ({ page }) => {
    await seedPreferences(page, 'de', 'light');
    await gotoReady(page, '/settings');
    await page.getByRole('switch', { name: 'Dunkelmodus umschalten' }).click();
    await expect(page.locator('html')).toHaveClass(/dark-theme/);
    await page.reload();
    await expect(page.locator('html')).toHaveClass(/dark-theme/);
  });

  test('Arbeitstage: einen weiteren Tag hinzufügen und speichern verdoppelt keine Tage', async ({ page }) => {
    await seedPreferences(page, 'de', 'light');
    await gotoReady(page, '/settings');
    await page.getByRole('button', { name: /Arbeitstage/ }).first().click();
    await page.getByRole('option', { name: 'Sa' }).click();
    await page.getByRole('button', { name: 'Speichern' }).click();

    const row = page.getByRole('button', { name: /Arbeitstage/ }).first();
    await expect(row).toContainText('Mo, Di, Mi, Do, Fr, Sa');
    await expect(row).not.toContainText('Mo, Mo');
    // 40 h auf 6 Tage = 6,7 h/Tag (mit verdoppelten Tagen wären es 3,6 h/Tag).
    await expect(page.getByText('≈ 6.7 h/Tag')).toBeVisible();
    const stored = await page.evaluate(() => JSON.parse(localStorage.getItem('user_settings')!).workdays);
    expect(stored).toEqual([1, 2, 3, 4, 5, 6]);
  });

  test('Sprachwechsel auf Englisch übersetzt die Navigation', async ({ page, isMobile }) => {
    await page.addInitScript(() => localStorage.removeItem('locale'));
    await gotoReady(page, '/settings');
    await page.getByRole('radio', { name: 'Englisch' }).click();
    const nav = isMobile ? page.getByRole('navigation', { name: 'Hauptnavigation' }) : page.getByRole('navigation');
    await expect(nav.getByRole('link', { name: 'Reports' })).toBeVisible();
  });
});
