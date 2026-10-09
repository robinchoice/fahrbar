import { createTeamKey, today } from '@app/shared';
import { expect, test } from '@playwright/test';
import postgres from 'postgres';

const sql = postgres(process.env.DATABASE_URL!, { connection: { timezone: 'UTC' }, onnotice: () => {} });
const slug = `e2e-${crypto.randomUUID().slice(0, 8)}`;

test.beforeAll(async () => {
  // The same key as the API tests, see AGENTS.md
  const key = await createTeamKey('local test passphrase');
  await sql`insert into team_key (public_key, encrypted_private_key, salt, iv, iterations)
    values (${key.publicKey}, ${key.encryptedPrivateKey}, ${key.salt}, ${key.iv}, ${key.iterations})
    on conflict do nothing`;
  const [practice] = await sql`insert into practices (slug, name, address)
    values (${slug}, 'Praxis Dr. Albrecht', 'Bertoldstraße 12, 79098 Freiburg') returning id`;
  await sql`insert into mornings (practice_id, date, start, "end", capacity)
    values (${practice!.id}, ${today(new Date(Date.now() + 4 * 24 * 60 * 60 * 1000))}, '08:00', '12:00', 4)`;
});

test.afterAll(async () => {
  await sql`delete from practices where slug = ${slug}`;
  await sql.end();
});

// Console errors fail the test, CSP violations included
let errors: string[] = [];
test.beforeEach(({ page }) => {
  errors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', (err) => errors.push(err.message));
});
test.afterEach(() => expect(errors).toEqual([]));

test('the practice link carries its own preview title', async ({ request }) => {
  const html = await (await request.get(`/p/${slug}`)).text();
  expect(html).toContain('<meta property="og:title" content="fahrbar · Praxis Dr. Albrecht"');
});

test('a patient books in two steps and cancels with the link', async ({ page }) => {
  // Buttons work once hydrated
  await page.goto(`/p/${slug}`, { waitUntil: 'networkidle' });
  await page.getByRole('button', { name: '09:00' }).click();
  await page.getByRole('button', { name: 'Weiter zu Ziel und Auto' }).click();

  await expect(page.getByRole('button', { name: 'Buchen · 49 € bar' })).toBeDisabled();
  await page.getByLabel('Vorname', { exact: true }).fill('Helga');
  await page.getByLabel('Straße und Hausnummer').fill('Schwarzwaldstraße 91');
  await page.getByLabel('PLZ und Ort').fill('79117 Freiburg');
  await page.getByLabel('Kennzeichen', { exact: true }).fill('FR-HT 315');
  await page.getByLabel('Telefon', { exact: true }).fill('0761 5523 019');
  await page.getByLabel('Ich lege 49 € abgezählt im Umschlag bereit.').check();
  await page.getByRole('button', { name: 'Buchen · 49 € bar' }).click();

  await expect(page.getByRole('heading', { name: 'Wir holen Sie ab.' })).toBeVisible();
  await expect(page.getByText('Helga', { exact: true })).toBeVisible();
  await expect(page.getByText('ca. 10:30 Uhr in der Praxis')).toBeVisible();

  // The server only holds ciphertext
  const stored = await sql`select r.payload from rides r join mornings m on m.id = r.morning_id
    join practices p on p.id = m.practice_id where p.slug = ${slug}`;
  expect(stored).toHaveLength(1);
  expect(stored[0]!.payload).toMatch(/^v1\./);
  expect(stored[0]!.payload).not.toContain('Helga');

  const link = (await page.getByRole('link', { name: /\/b\// }).textContent())!;
  await page.goto(link);
  await expect(page.getByText('Gebucht. Wir rufen Sie am Vortag an.')).toBeVisible();
  await page.getByRole('button', { name: 'Fahrt absagen' }).click();
  await page.getByRole('button', { name: 'Ja, Fahrt absagen' }).click();
  await expect(page.getByText('Die Fahrt ist abgesagt und gelöscht.')).toBeVisible();
});

test('an unknown practice link explains itself', async ({ page }) => {
  const response = await page.goto('/p/gibt-es-nicht');
  expect(response?.status()).toBe(404);
  await expect(page.getByText('Diesen Buchungslink gibt es nicht.')).toBeVisible();
  // The 404 of the page itself is expected
  errors = errors.filter((e) => !e.includes('404'));
});
