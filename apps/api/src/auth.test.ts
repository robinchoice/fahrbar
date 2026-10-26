import { afterAll, beforeAll, beforeEach, expect, setSystemTime, spyOn, test } from 'bun:test';
import { createDb, migrateDb, passkeys, rateLimits, sessions, users } from '@app/db';
import { messages } from '@app/shared';
import { eq } from 'drizzle-orm';
import { z } from 'zod';
import { createApp } from './app';
import { generateToken, hashToken } from './middleware/auth';
import { altchaPayload } from './testing';

const db = createDb(process.env.DATABASE_URL);
const app = createApp(db);
const log = spyOn(console, 'log');

beforeAll(() => migrateDb(process.env.DATABASE_URL));
afterAll(() => db.$client.end());

// Most tests sign up fresh addresses, the closed case has its own test
process.env.SIGNUP_OPEN = 'true';

const freshEmail = () => `test-${crypto.randomUUID()}@example.com`;

// Rate limits live in the database, so each run counts against its own address
let ip = crypto.randomUUID();
beforeEach(() => {
  ip = crypto.randomUUID();
});

async function postWithAltcha(path: string, body: object, headers: Record<string, string> = {}) {
  return post(path, { ...body, altcha: await altchaPayload(app) }, headers);
}

function post(path: string, body: unknown, headers: Record<string, string> = {}) {
  return app.request(`/api/v1${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-forwarded-for': ip, ...headers },
    body: JSON.stringify(body),
  });
}

async function body(res: Response | Promise<Response>): Promise<unknown> {
  return (await res).json();
}

// For fields a test reads on, the schema checks they are there
async function read<T extends z.ZodType>(res: Response | Promise<Response>, schema: T): Promise<z.output<T>> {
  return schema.parse(await body(res));
}

const userAnswer = z.object({ user: z.object({ id: z.string(), email: z.string() }), token: z.string().optional() });

// Without SMTP_HOST the login mail lands in the log
function lastMail() {
  return log.mock.calls.map((args) => String(args[0])).findLast((line) => line.startsWith('[mail]'));
}

const mailCount = () => log.mock.calls.filter((args) => String(args[0]).startsWith('[mail]')).length;

function lastMailedToken() {
  return lastMail()?.match(/token=([0-9a-f]+)/)?.[1];
}

function lastMailedCode() {
  return lastMail()?.match(/(\d{6}) ist dein Login-Code/)?.[1];
}

const otherCode = (code: string) => (code === '000000' ? '000001' : '000000');

test('health checks the database', async () => {
  const res = await app.request('/api/health');
  expect(res.status).toBe(200);
  expect(await body(res)).toMatchObject({ status: 'ok', revision: expect.any(String) });
});

test('magic link logs in, creates the account and logs out', async () => {
  const email = freshEmail();
  expect((await postWithAltcha('/auth/magic-link', { email: ` ${email.toUpperCase()} ` })).status).toBe(200);
  const token = lastMailedToken()!;

  const verify = await post('/auth/verify', { token });
  expect(verify.status).toBe(200);
  expect(await body(verify)).toMatchObject({ user: { email, name: email.split('@')[0] } });
  const session = verify.headers.get('set-cookie')!.match(/session=([0-9a-f]+)/)![1]!;

  const me = await app.request('/api/v1/auth/me', { headers: { cookie: `session=${session}` } });
  expect(await body(me)).toMatchObject({ user: { email } });

  // Native clients send the same token as a bearer token
  const rename = await app.request('/api/v1/auth/me', {
    method: 'PATCH',
    headers: { authorization: `Bearer ${session}`, 'content-type': 'application/json' },
    body: JSON.stringify({ name: 'Robin' }),
  });
  expect(await body(rename)).toMatchObject({ user: { name: 'Robin' } });

  expect((await post('/auth/verify', { token })).status).toBe(400);

  await post('/auth/logout', {}, { cookie: `session=${session}` });
  const after = await app.request('/api/v1/auth/me', { headers: { cookie: `session=${session}` } });
  expect(await body(after)).toEqual({ user: null });
});

test('login mails need an ALTCHA solution that is valid and unused', async () => {
  const email = freshEmail();
  const mails = mailCount();
  const missing = await post('/auth/magic-link', { email }, { 'accept-language': 'en' });
  expect(missing.status).toBe(403);
  expect(await body(missing)).toEqual({ error: messages.en.altchaFailed });
  expect((await post('/auth/code', { email, altcha: btoa('nonsense') })).status).toBe(403);

  const altcha = await altchaPayload(app);
  const { challenge, solution } = JSON.parse(atob(altcha));
  const easier = { ...challenge, parameters: { ...challenge.parameters, cost: 1 } };
  const wrong = { ...solution, counter: solution.counter + 1 };
  for (const forged of [
    { challenge: easier, solution },
    { challenge, solution: wrong },
  ])
    expect((await post('/auth/code', { email, altcha: btoa(JSON.stringify(forged)) })).status).toBe(403);
  expect(mailCount()).toBe(mails);

  expect((await post('/auth/code', { email, altcha })).status).toBe(200);
  expect((await post('/auth/magic-link', { email, altcha })).status).toBe(403);
  expect(mailCount()).toBe(mails + 1);
});

test('an ALTCHA solution expires after ten minutes', async () => {
  const altcha = await altchaPayload(app);
  setSystemTime(new Date(Date.now() + 11 * 60 * 1000));
  try {
    expect((await post('/auth/magic-link', { email: freshEmail(), altcha })).status).toBe(403);
  } finally {
    setSystemTime();
  }
});

test('requests without ALTCHA leave the rate limits of an address alone', async () => {
  const email = freshEmail();
  for (let i = 0; i < 10; i++) await post('/auth/magic-link', { email });
  expect((await postWithAltcha('/auth/magic-link', { email })).status).toBe(200);
});

test('a second login reuses the account', async () => {
  const email = freshEmail();
  const ids: string[] = [];
  for (let i = 0; i < 2; i++) {
    await postWithAltcha('/auth/magic-link', { email });
    ids.push((await read(post('/auth/verify', { token: lastMailedToken() }), userAnswer)).user.id);
  }
  expect(ids[0]).toBe(ids[1]);
});

test('magic link checks allow 60 attempts per IP and leave blocked links usable', async () => {
  const email = freshEmail();
  expect((await postWithAltcha('/auth/magic-link', { email })).status).toBe(200);
  const token = lastMailedToken()!;

  const attempts = await Promise.all(Array.from({ length: 60 }, () => post('/auth/verify', { token: 'invalid' })));
  expect(attempts.map((res) => res.status)).toEqual(Array(60).fill(400));
  const blocked = await post('/auth/verify', { token }, { 'accept-language': 'en' });
  expect(blocked.status).toBe(429);
  expect(await body(blocked)).toEqual({ error: messages.en.tooManyRequests });
  expect(blocked.headers.get('set-cookie')).toBeNull();

  expect((await post('/auth/verify', { token }, { 'x-forwarded-for': crypto.randomUUID() })).status).toBe(200);

  expect((await postWithAltcha('/auth/magic-link', { email })).status).toBe(200);
  const nextToken = lastMailedToken()!;
  expect((await post('/auth/verify', { token: nextToken })).status).toBe(429);
  await db
    .update(rateLimits)
    .set({ resetAt: new Date(Date.now() - 1) })
    .where(eq(rateLimits.key, `link-checks-per-ip:${ip}`));
  expect((await post('/auth/verify', { token: nextToken })).status).toBe(200);
});

test('protected routes need a session', async () => {
  const res = await app.request('/api/v1/auth/me', { method: 'PATCH', body: '{}' });
  expect(res.status).toBe(401);
});

test('login mails per address are rate limited', async () => {
  const email = freshEmail();
  const statuses: number[] = [];
  for (let i = 0; i < 6; i++) statuses.push((await postWithAltcha('/auth/magic-link', { email })).status);
  expect(statuses).toEqual([200, 200, 200, 200, 200, 429]);
});

test('invalid input answers with an error message', async () => {
  const res = await postWithAltcha('/auth/magic-link', { email: 'no-address' });
  expect(res.status).toBe(400);
  expect(await body(res)).toEqual({ error: expect.any(String) });
});

test('errors and mails follow Accept-Language, German by default', async () => {
  const english = { 'accept-language': 'fr-FR,fr;q=0.9,en;q=0.8' };
  expect(await body(postWithAltcha('/auth/magic-link', { email: 'no-address' }, english))).toEqual({
    error: 'The email address is invalid.',
  });
  expect(await body(postWithAltcha('/auth/magic-link', { email: 'no-address' }))).toEqual({
    error: 'Die E-Mail-Adresse ist ungültig.',
  });

  await postWithAltcha('/auth/code', { email: freshEmail() }, english);
  expect(lastMail()).toContain('is your login code');
});

test('apps log in with a code and get a bearer token', async () => {
  const email = freshEmail();
  expect((await postWithAltcha('/auth/code', { email })).status).toBe(200);
  const code = lastMailedCode()!;

  expect((await post('/auth/code/verify', { email, code: otherCode(code) })).status).toBe(400);
  const verify = await post('/auth/code/verify', { email, code });
  expect(verify.status).toBe(200);
  expect(verify.headers.get('set-cookie')).toBeNull();
  const { user, token } = await read(verify, userAnswer);
  expect(user.email).toBe(email);

  const me = await app.request('/api/v1/auth/me', { headers: { authorization: `Bearer ${token}` } });
  expect(await body(me)).toMatchObject({ user: { id: user.id } });

  expect((await post('/auth/code/verify', { email, code })).status).toBe(400);
});

test('a code stops working after five wrong tries', async () => {
  const email = freshEmail();
  await postWithAltcha('/auth/code', { email });
  const code = lastMailedCode()!;
  for (let i = 0; i < 5; i++) await post('/auth/code/verify', { email, code: otherCode(code) });
  expect((await post('/auth/code/verify', { email, code })).status).toBe(400);
});

test('closed sign-up mails only existing accounts, the allowlist and the team', async () => {
  const allowed = freshEmail();
  const teamMember = freshEmail();
  const [existing] = await db.insert(users).values({ email: freshEmail(), name: 'Lena' }).returning();
  delete process.env.SIGNUP_OPEN;
  process.env.SIGNUP_ALLOWLIST = ` ${allowed.toUpperCase()} , someone@example.com`;
  process.env.TEAM_EMAILS = teamMember;
  try {
    const mails = mailCount();
    const stranger = freshEmail();
    const link = await postWithAltcha('/auth/magic-link', { email: stranger });
    expect(link.status).toBe(403);
    expect(await body(link)).toEqual({
      error: 'Die Registrierung ist noch geschlossen. Für diese Adresse gibt es noch kein Konto.',
    });
    expect((await postWithAltcha('/auth/code', { email: stranger })).status).toBe(403);
    expect(mailCount()).toBe(mails);

    expect((await postWithAltcha('/auth/code', { email: existing!.email })).status).toBe(200);
    expect((await postWithAltcha('/auth/magic-link', { email: teamMember })).status).toBe(200);
    expect((await postWithAltcha('/auth/magic-link', { email: allowed })).status).toBe(200);
    expect(await body(post('/auth/verify', { token: lastMailedToken() }))).toMatchObject({ user: { email: allowed } });

    // login-link still works, Savor's test account needs no allowlist entry
    const run = Bun.spawnSync(['bun', 'src/login-link.ts', stranger], {
      env: { ...process.env, APP_URL: 'https://app.test' },
    });
    const token = new URL(run.stdout.toString().trim()).searchParams.get('token');
    expect(await body(post('/auth/verify', { token }))).toMatchObject({ user: { email: stranger } });
  } finally {
    process.env.SIGNUP_OPEN = 'true';
    delete process.env.SIGNUP_ALLOWLIST;
    delete process.env.TEAM_EMAILS;
  }
});

async function sessionFor(email: string) {
  const [user] = await db.insert(users).values({ email, name: 'Robin' }).returning({ id: users.id });
  const token = generateToken();
  await db
    .insert(sessions)
    .values({ userId: user!.id, tokenHash: hashToken(token), expiresAt: new Date(Date.now() + 60_000) });
  return { cookie: `session=${token}` };
}

test('admins invite testers past the closed sign-up, others get 403', async () => {
  const admin = freshEmail();
  const asAdmin = await sessionFor(admin);
  const asUser = await sessionFor(freshEmail());
  delete process.env.SIGNUP_OPEN;
  process.env.ADMIN_EMAILS = `someone@example.com, ${admin.toUpperCase()}`;
  try {
    const me = await app.request('/api/v1/auth/me', { headers: asAdmin });
    expect(await body(me)).toMatchObject({ user: { admin: true } });

    const tester = freshEmail();
    expect((await post('/auth/invite', { email: tester })).status).toBe(401);
    const denied = await post('/auth/invite', { email: tester }, asUser);
    expect(denied.status).toBe(403);
    expect(await body(denied)).toEqual({ error: 'Nur für Admins' });
    expect(await db.select().from(users).where(eq(users.email, tester))).toEqual([]);

    expect((await post('/auth/invite', { email: tester }, asAdmin)).status).toBe(200);
    expect(lastMail()).toStartWith(`[mail] To ${tester}:`);
    const verify = await body(post('/auth/verify', { token: lastMailedToken() }));
    expect(verify).toMatchObject({ user: { email: tester, admin: false } });

    // From now on the tester logs in like any existing account
    expect((await postWithAltcha('/auth/magic-link', { email: tester })).status).toBe(200);
    expect(process.env.SIGNUP_OPEN).toBeUndefined();
  } finally {
    process.env.SIGNUP_OPEN = 'true';
    delete process.env.ADMIN_EMAILS;
  }
});

test('login-link prints a magic link that logs in', async () => {
  const email = freshEmail();
  const run = Bun.spawnSync(['bun', 'src/login-link.ts', email], {
    env: { ...process.env, APP_URL: 'https://app.test' },
  });
  const link = new URL(run.stdout.toString().trim());
  expect(link.origin + link.pathname).toBe('https://app.test/auth/verify');

  const verify = await post('/auth/verify', { token: link.searchParams.get('token') });
  expect(await body(verify)).toMatchObject({ user: { email } });
});

test('a session in use is renewed', async () => {
  const [user] = await db.insert(users).values({ email: freshEmail(), name: 'Lena' }).returning({ id: users.id });
  const token = generateToken();
  const [session] = await db
    .insert(sessions)
    .values({ userId: user!.id, tokenHash: hashToken(token), expiresAt: new Date(Date.now() + 60_000) })
    .returning({ id: sessions.id });

  const me = await app.request('/api/v1/auth/me', { headers: { cookie: `session=${token}` } });
  expect(me.headers.get('set-cookie')).toContain(`session=${token}`);
  const [renewed] = await db.select().from(sessions).where(eq(sessions.id, session!.id));
  expect(renewed!.expiresAt.getTime()).toBeGreaterThan(Date.now() + 364 * 24 * 60 * 60 * 1000);

  // Renewed sessions are left alone for a day
  const again = await app.request('/api/v1/auth/me', { headers: { cookie: `session=${token}` } });
  expect(again.headers.get('set-cookie')).toBeNull();
});

// The full ceremony runs in the browser test with Chromium's virtual authenticator
test('passkeys belong to logged-in accounts and fail closed', async () => {
  const asOwner = await sessionFor(freshEmail());
  const asOther = await sessionFor(freshEmail());
  expect((await post('/auth/passkeys/register/options', {})).status).toBe(401);

  const rpID = new URL(process.env.APP_URL).hostname;
  const register = await body(post('/auth/passkeys/register/options', {}, asOwner));
  expect(register).toMatchObject({ rp: { id: rpID }, authenticatorSelection: { residentKey: 'required' } });

  const login = await body(post('/auth/passkeys/login/options', {}));
  expect(login).toMatchObject({ rpId: rpID });
  expect(login).not.toHaveProperty('allowCredentials');

  const response = {
    id: 'unknown',
    rawId: 'unknown',
    type: 'public-key',
    response: { clientDataJSON: 'e30', authenticatorData: 'AA', signature: 'AA' },
    clientExtensionResults: {},
  };
  const unknown = await post('/auth/passkeys/login', { response });
  expect(unknown.status).toBe(400);
  expect(await body(unknown)).toMatchObject({ error: 'Diesen Passkey kennen wir nicht. Melde dich per Mail an.' });

  const owner = (await read(app.request('/api/v1/auth/me', { headers: asOwner }), userAnswer)).user;
  const id = `test-${crypto.randomUUID()}`;
  await db.insert(passkeys).values({ id, userId: owner.id, publicKey: Buffer.from([1]), counter: 0, backedUp: true });
  const forged = await post('/auth/passkeys/login', { response: { ...response, id, rawId: id } });
  expect(forged.status).toBe(400);
  expect(forged.headers.get('set-cookie')).toBeNull();

  const del = (headers: Record<string, string>) =>
    app.request(`/api/v1/auth/passkeys/${id}`, { method: 'DELETE', headers });
  expect((await del(asOther)).status).toBe(404);
  expect(await body(app.request('/api/v1/auth/passkeys', { headers: asOwner }))).toEqual({
    passkeys: [expect.any(Object)],
  });
  expect((await del(asOwner)).status).toBe(200);
  expect(await body(app.request('/api/v1/auth/passkeys', { headers: asOwner }))).toEqual({ passkeys: [] });
});

test('the web redeems the code from its login mail into a cookie without exposing the token', async () => {
  const email = freshEmail();
  expect((await postWithAltcha('/auth/magic-link', { email }, { 'x-forwarded-for': crypto.randomUUID() })).status).toBe(
    200,
  );
  const code = lastMailedCode()!;
  expect(code).toMatch(/^\d{6}$/);
  expect(lastMail()).toContain(`Oder gib auf der Login-Seite diesen Code ein: ${code}`);
  const verify = await post('/auth/code/verify', { email, code, cookie: true });
  expect(verify.status).toBe(200);
  const cookie = verify.headers.get('set-cookie')!;
  expect(cookie).toContain('HttpOnly');
  expect(cookie).toContain('Max-Age=31536000');
  const result = await read(verify, userAnswer);
  expect(result.user.email).toBe(email);
  expect(result.token).toBeUndefined();
  const me = await body(app.request('/api/v1/auth/me', { headers: { cookie } }));
  expect(me).toMatchObject({ user: { email } });
  expect((await post('/auth/code/verify', { email, code, cookie: true })).status).toBe(400);
});

test('an address removed from the allowlist cannot redeem an issued link or code', async () => {
  const email = freshEmail();
  expect((await postWithAltcha('/auth/magic-link', { email }, { 'x-forwarded-for': crypto.randomUUID() })).status).toBe(
    200,
  );
  const token = lastMailedToken();
  const code = lastMailedCode();
  delete process.env.SIGNUP_OPEN;
  try {
    const link = await post('/auth/verify', { token });
    expect(link.status).toBe(403);
    expect(link.headers.get('set-cookie')).toBeNull();
    const verify = await post('/auth/code/verify', { email, code, cookie: true });
    expect(verify.status).toBe(403);
    expect(verify.headers.get('set-cookie')).toBeNull();
    expect(await db.select().from(users).where(eq(users.email, email))).toEqual([]);
  } finally {
    process.env.SIGNUP_OPEN = 'true';
  }
});

test('bearer sessions slide to 365 days without setting a web cookie', async () => {
  const asUser = await sessionFor(freshEmail());
  const token = asUser.cookie.slice('session='.length);
  const me = await app.request('/api/v1/auth/me', { headers: { authorization: `Bearer ${token}` } });
  expect(me.status).toBe(200);
  expect(me.headers.get('set-cookie')).toBeNull();
  const [row] = await db
    .select()
    .from(sessions)
    .where(eq(sessions.tokenHash, hashToken(token)));
  expect(row!.expiresAt.getTime()).toBeGreaterThan(Date.now() + 364 * 24 * 60 * 60 * 1000);
});
