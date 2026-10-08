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

  test('Sprachwechsel auf Englisch übersetzt die Navigation', async ({ page, isMobile }) => {
    await page.addInitScript(() => localStorage.removeItem('locale'));
    await gotoReady(page, '/settings');
    await page.getByRole('radio', { name: 'Englisch' }).click();
    const nav = isMobile ? page.getByRole('navigation', { name: 'Hauptnavigation' }) : page.getByRole('navigation');
    await expect(nav.getByRole('link', { name: 'Reports' })).toBeVisible();
  });
});
