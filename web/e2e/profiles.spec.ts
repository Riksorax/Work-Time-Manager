import { Page } from '@playwright/test';
import { EMULATORS_ENABLED, expect, seedEntry, test } from './account';

/** Manuelle Prüfungen aus #380/#388: Profilwechsel-Dialog bei laufendem Timer, Anlegen und Löschen. */

test.skip(!EMULATORS_ENABLED, 'Firebase-Emulatoren aus (E2E_EMULATORS=1 setzen)');
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium', 'Tests mit Konto laufen nur in Chromium');
});

const switcher = (page: Page) => page.getByRole('button', { name: 'Profil wechseln' });

/** Eintrag von heute 08:00 ohne Ende, es sei denn, es ist noch vor 08:00 (dann eine Minute vor jetzt). */
function runningSince(): Date {
  const now = new Date();
  const eight = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 8, 0);
  return eight < now ? eight : new Date(now.getTime() - 60_000);
}

test.describe('Profilwechsler (#380/#388)', () => {
  test('listet Standard- und weitere Profile, aktives Profil ist markiert', async ({ page, account }) => {
    await account.setPremium(true);
    await account.addProfile('Arbeitgeber B');
    await account.signIn();

    await switcher(page).click();
    await expect(page.getByRole('menuitem', { name: /Standard/ })).toBeVisible();
    await expect(page.getByRole('menuitem', { name: /Arbeitgeber B/ })).toBeVisible();
    await expect(page.getByRole('menuitem', { name: /Standard/ })).toContainText('check');
  });

  test('Wechsel ohne laufenden Timer geht direkt, ohne Dialog', async ({ page, account }) => {
    await account.setPremium(true);
    await account.addProfile('Arbeitgeber B');
    await account.signIn();

    await switcher(page).click();
    await page.getByRole('menuitem', { name: /Arbeitgeber B/ }).click();
    await expect(page.getByRole('dialog')).toHaveCount(0);

    await switcher(page).click();
    await expect(page.getByRole('menuitem', { name: /Arbeitgeber B/ })).toContainText('check');
  });

  test('laufender Timer: Abbrechen bleibt im Profil und lässt den Timer laufen', async ({ page, account }) => {
    await account.setPremium(true);
    await account.addProfile('Arbeitgeber B');
    await seedEntry(account.user.uid, 'default', { start: runningSince() });
    await account.signIn();
    await expect(page.getByRole('button', { name: 'Zeiterfassung beenden' })).toBeVisible();

    await switcher(page).click();
    await page.getByRole('menuitem', { name: /Arbeitgeber B/ }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toContainText('Zeiterfassung läuft');
    await dialog.getByRole('button', { name: 'Abbrechen' }).click();

    await expect(dialog).toBeHidden();
    await expect(page.getByRole('button', { name: 'Zeiterfassung beenden' })).toBeVisible();
    await switcher(page).click();
    await expect(page.getByRole('menuitem', { name: /Standard/ })).toContainText('check');
  });

  test('laufender Timer: „Beenden und wechseln" speichert das Ende und wechselt', async ({ page, account }) => {
    await account.setPremium(true);
    await account.addProfile('Arbeitgeber B');
    await seedEntry(account.user.uid, 'default', { start: runningSince() });
    await account.signIn();
    await expect(page.getByRole('button', { name: 'Zeiterfassung beenden' })).toBeVisible();

    await switcher(page).click();
    await page.getByRole('menuitem', { name: /Arbeitgeber B/ }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'Beenden und wechseln' }).click();

    await expect(page.getByRole('dialog')).toHaveCount(0);
    // Im neuen Profil läuft nichts.
    await expect(page.getByRole('button', { name: 'Zeiterfassung starten' })).toBeVisible();
    // Das Ende wurde im Standard-Profil gespeichert (kein verlorener Eintrag).
    expect(account.backend.calls).toContain('PUT /work-entries');
  });
});

test.describe('Profile anlegen und löschen', () => {
  test('ohne Premium: Hinweis statt Dialog', async ({ page, account }) => {
    await account.signIn();
    await switcher(page).click();
    await page.getByRole('menuitem', { name: 'Neues Profil' }).click();
    await expect(page.getByText('Zusätzliche Profile sind ein Premium-Feature.')).toBeVisible();
    await expect(page.getByRole('dialog')).toHaveCount(0);
  });

  test('Premium: Profil anlegen, wechseln und wieder löschen', async ({ page, account }) => {
    await account.setPremium(true);
    await account.signIn();

    await switcher(page).click();
    await page.getByRole('menuitem', { name: 'Neues Profil' }).click();
    await page.getByRole('dialog').getByLabel('Profilname').fill('Nebenjob');
    await page.getByRole('dialog').getByRole('button', { name: 'Anlegen' }).click();
    await expect(page.getByText('Profil "Nebenjob" angelegt.')).toBeVisible();

    await switcher(page).click();
    await expect(page.getByRole('menuitem', { name: /Nebenjob/ })).toBeVisible();
    await page.getByRole('menuitem', { name: 'Profile verwalten' }).click();

    const manage = page.getByRole('dialog');
    await manage.getByRole('button', { name: 'Profil löschen' }).click();
    await page.getByRole('dialog').filter({ hasText: 'Profil löschen?' }).getByRole('button', { name: /Löschen|Ja/ }).click();
    await expect(page.getByText('Profil "Nebenjob" gelöscht.')).toBeVisible();
  });
});
