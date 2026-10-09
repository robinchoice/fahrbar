import { createHash, randomBytes } from 'node:crypto';
import { expect, type Page, test } from '@playwright/test';
import postgres from 'postgres';

const sql = postgres(process.env.DATABASE_URL!, { connection: { timezone: 'UTC' }, onnotice: () => {} });
test.afterAll(() => sql.end());

// Console errors fail the test, CSP violations of the screenshot included
let errors: string[] = [];
test.beforeEach(({ page }) => {
  errors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', (err) => errors.push(err.message));
});
test.afterEach(() => expect(errors).toEqual([]));

async function logIn(page: Page) {
  const email = `e2e-${crypto.randomUUID()}@example.com`;
  const token = randomBytes(32).toString('hex');
  const tokenHash = createHash('sha256').update(token).digest('hex');
  await sql`insert into magic_links (email, token_hash, expires_at)
    values (${email}, ${tokenHash}, ${new Date(Date.now() + 15 * 60_000)})`;
  await page.goto(`/auth/verify?token=${token}`);
  await expect(page).toHaveURL(/\/team$/);
  return email;
}

const reports = (email: string) => sql`select f.kind, f.message, f.screenshot, f.context
  from feedback f join users u on u.id = f.user_id where u.email = ${email} order by f.created_at`;

test('the bug button sends a marked screenshot of the page', async ({ page }) => {
  const email = await logIn(page);
  await page.getByRole('button', { name: 'Fehler melden' }).click();

  const panel = page.getByRole('dialog', { name: 'Fehler melden' });
  await expect(panel.getByRole('img', { name: 'Screenshot' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Fehler melden' })).toBeHidden();

  await panel.getByRole('button', { name: 'Stelle markieren' }).click();
  const box = (await page.locator('.mark img').boundingBox())!;
  await page.mouse.move(box.x + box.width * 0.2, box.y + box.height * 0.2);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width * 0.5, box.y + box.height * 0.4, { steps: 5 });
  await page.mouse.up();
  await page.getByRole('button', { name: 'Fertig' }).click();

  await panel.getByRole('textbox').fill('Speichern hängt');
  await panel.getByRole('button', { name: 'Senden' }).click();
  await expect(page.getByText('Danke! Wir melden uns per Mail.')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Fehler melden' })).toBeVisible();

  const [report] = await reports(email);
  expect(report).toMatchObject({ kind: 'bug', message: 'Speichern hängt' });
  expect([...report!.screenshot.subarray(0, 3)]).toEqual([0xff, 0xd8, 0xff]);
  expect(report!.context).toMatchObject({ platform: 'web', page: '/team', locale: 'de' });
});

test('the header takes ideas without a screenshot', async ({ page }) => {
  const email = await logIn(page);
  await page.getByRole('button', { name: 'Feedback geben' }).click();

  const panel = page.getByRole('dialog', { name: 'Feedback geben' });
  await expect(panel.getByRole('img')).toHaveCount(0);
  await panel.getByRole('textbox').fill('Ein dunkler Modus wäre schön');
  await panel.getByRole('button', { name: 'Senden' }).click();
  await expect(page.getByText('Danke! Wir melden uns per Mail.')).toBeVisible();

  const [report] = await reports(email);
  expect(report).toMatchObject({ kind: 'idea', screenshot: null });
});

test('the test mode switch in the footer hides the bug button', async ({ page }) => {
  await logIn(page);
  const testMode = page.getByRole('checkbox', { name: 'Testmodus' });
  await expect(testMode).toBeChecked();

  await testMode.uncheck();
  await expect(page.getByRole('button', { name: 'Fehler melden' })).toBeHidden();
  await page.reload();
  await expect(testMode).not.toBeChecked();
  await expect(page.getByRole('button', { name: 'Fehler melden' })).toBeHidden();

  await testMode.check();
  await expect(page.getByRole('button', { name: 'Fehler melden' })).toBeVisible();
});
