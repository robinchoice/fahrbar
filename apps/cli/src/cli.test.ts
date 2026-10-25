import { afterAll, beforeAll, beforeEach, expect, spyOn, test } from 'bun:test';
import { mkdtemp, readFile, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createDb, magicLinks, migrateDb, mornings, practices, rateLimits, rides, users } from '@app/db';
import { addDays, messages, today } from '@app/shared';
import { z } from 'zod';
import { createApp } from '../../api/src/app';
import { hashToken } from '../../api/src/middleware/auth';
import { run } from './cli';
import { SLUG, sessionFile } from './config';

// The CLI runs in-process against the real API on a free port, with the test database
const db = createDb(process.env.DATABASE_URL);
// Request log and mails stay out of the test output
const log = spyOn(console, 'log').mockImplementation(() => {});
let server: ReturnType<typeof Bun.serve>;
let url = '';

beforeAll(async () => {
  await migrateDb(process.env.DATABASE_URL);
  server = Bun.serve({ port: 0, fetch: createApp(db).fetch });
  url = server.url.origin;
});
beforeEach(() => db.delete(rateLimits));
const folders: string[] = [];
afterAll(async () => {
  await server.stop(true);
  await db.$client.end();
  await Promise.all(folders.map((path) => rm(path, { recursive: true, force: true })));
});

process.env.SIGNUP_OPEN = 'true';
const de = messages.de;
const storedSchema = z.object({ token: z.string() });
const freshEmail = () => `cli-${crypto.randomUUID()}@example.com`;

// Without SMTP_HOST the login mail lands in the log
const mails = () => log.mock.calls.map((args) => String(args[0])).filter((line) => line.startsWith('[mail]'));
const lastCode = () =>
  mails()
    .at(-1)
    ?.match(/(\d{6}) ist dein Login-Code/)?.[1] ?? '';

// One device: its own config folder, so its own token. Answers the code
// question from the last mail, the email question with `email`.
async function device(env: Record<string, string> = { LANG: 'de_DE.UTF-8' }) {
  const deviceEnv = { XDG_CONFIG_HOME: await mkdtemp(join(tmpdir(), 'cli-')), ...env };
  folders.push(deviceEnv.XDG_CONFIG_HOME);
  // Adds --url of the test API unless raw or the call names one
  const cli = async (args: string[], { email = '', stdin = '', raw = false } = {}) => {
    const out: string[] = [];
    const err: string[] = [];
    const code = await run(raw || args.length === 0 || args.includes('--url') ? args : [...args, '--url', url], {
      env: deviceEnv,
      out: (text) => out.push(text),
      err: (text) => err.push(text),
      ask: async (question) => (question === de.cliAskCode ? lastCode() : email),
      stdin: async () => stdin,
    });
    return { code, out: out.join('\n'), err: err.join('\n'), json: () => JSON.parse(out.join('\n')) };
  };
  const token = async () => storedSchema.parse(JSON.parse(await readFile(sessionFile(deviceEnv), 'utf8'))).token;
  return { cli, token, env: deviceEnv };
}

const sessionCount = async (token: string) =>
  (await db.$client`select count(*)::int as n from sessions where token_hash = ${hashToken(token)}`)[0]!.n;

const me = (token: string) =>
  fetch(`${url}/api/v1/auth/me`, { headers: { authorization: `Bearer ${token}` } }).then((res) => res.json());

async function issueMagicLink(email: string) {
  const token = crypto.randomUUID();
  await db.insert(magicLinks).values({ email, tokenHash: hashToken(token), expiresAt: new Date(Date.now() + 60_000) });
  return token;
}

test('login with the mailed code stores a token only the user can read', async () => {
  const email = freshEmail();
  const { cli, token, env } = await device();

  const login = await cli(['login', '--json'], { email });
  expect(login.code).toBe(0);
  expect(login.json()).toMatchObject({ user: { email } });
  expect(login.err).toContain(de.cliCodeSent(email));
  expect((await stat(sessionFile(env))).mode & 0o777).toBe(0o600);
  expect(await sessionCount(await token())).toBe(1);

  expect(await cli(['whoami'])).toMatchObject({ code: 0, out: `${email.split('@')[0]} <${email}>` });
  expect((await cli(['whoami', '--json'])).json()).toMatchObject({ user: { email, admin: false } });
});

test('settings reads and changes the display name', async () => {
  const { cli } = await device();
  await cli(['login'], { email: freshEmail() });
  const changed = await cli(['settings', '--name', 'Ada', '--json']);
  expect(changed.code).toBe(0);
  expect(changed.json()).toMatchObject({ user: { name: 'Ada' } });
  expect((await cli(['settings'])).out).toContain(`${de.cliDisplayName}: Ada`);
  expect((await cli(['settings', '--updates', 'on'])).code).toBe(2);
});

test('rides lists mornings and ride metadata only for the team', async () => {
  const email = freshEmail();
  const previousTeam = process.env.TEAM_EMAILS;
  process.env.TEAM_EMAILS = email;
  try {
    const { cli } = await device();
    expect((await cli(['rides', '--json'])).code).toBe(3);
    await cli(['login'], { email });
    const [practice] = await db
      .insert(practices)
      .values({ slug: `cli-${crypto.randomUUID()}`, name: 'CLI practice', address: 'Test street 1' })
      .returning();
    const [morning] = await db
      .insert(mornings)
      .values({ practiceId: practice!.id, date: addDays(today(), 3), start: '08:00', end: '12:00', capacity: 4 })
      .returning();
    const [ride] = await db
      .insert(rides)
      .values({
        morningId: morning!.id,
        payload: 'v1.encrypted-test-payload',
        manageTokenHash: hashToken(crypto.randomUUID()),
      })
      .returning();

    const overview = await cli(['rides', '--json']);
    expect(overview.code).toBe(0);
    expect(overview.json()).toMatchObject({
      mornings: expect.arrayContaining([expect.objectContaining({ id: morning!.id, booked: 1 })]),
    });
    expect((await cli(['rides'])).out).toContain(`${morning!.id} · ${morning!.date} 08:00–12:00 · ${de.pickups(1)}/4`);
    const listed = await cli(['rides', '--morning', morning!.id, '--json']);
    expect(listed.code).toBe(0);
    expect(listed.json()).toMatchObject({
      morning: { id: morning!.id },
      rides: [{ id: ride!.id, status: 'new', createdAt: expect.any(String) }],
    });
    expect(listed.out).not.toContain('payload');
    const text = await cli(['rides', '--morning', morning!.id]);
    expect(text.out).toContain(`${ride!.id} · ${de.teamStatusNew}`);
    expect((await cli(['rides', '--morning', morning!.id, '--lang', 'en'])).out).toContain(messages.en.teamStatusNew);
    expect((await cli(['rides', '--morning', 'invalid'])).code).toBe(2);
    expect((await cli(['rides', '--morning', crypto.randomUUID()])).code).toBe(1);

    const outsider = await device();
    await outsider.cli(['login'], { email: freshEmail() });
    expect(await outsider.cli(['rides', '--json'])).toMatchObject({ code: 1 });
    expect((await outsider.cli(['rides', '--json'])).json()).toEqual({ error: de.notInTeam });
    expect((await outsider.cli(['rides', '--morning', morning!.id])).code).toBe(1);
  } finally {
    if (previousTeam === undefined) delete process.env.TEAM_EMAILS;
    else process.env.TEAM_EMAILS = previousTeam;
  }
});

test('every device has its own token, logout revokes only that one', async () => {
  const email = freshEmail();
  const laptop = await device();
  const server = await device();
  await laptop.cli(['login'], { email });
  await server.cli(['login'], { email });
  const laptopToken = await laptop.token();
  expect(laptopToken).not.toBe(await server.token());

  expect(await laptop.cli(['logout'])).toMatchObject({ code: 0, out: de.cliLoggedOut });
  expect(await sessionCount(laptopToken)).toBe(0);
  expect(await me(laptopToken)).toEqual({ user: null });
  expect(await laptop.cli(['whoami'])).toMatchObject({ code: 3, err: de.notLoggedIn });
  expect((await laptop.cli(['whoami', '--json'])).json()).toEqual({ error: de.notLoggedIn });

  expect((await server.cli(['whoami'])).code).toBe(0);

  // Logging in again replaces the token of the device and revokes the old one
  const oldToken = await server.token();
  await server.cli(['login'], { email });
  expect(await sessionCount(oldToken)).toBe(0);
  expect(await sessionCount(await server.token())).toBe(1);
});

test('a session revoked on the server logs the CLI out', async () => {
  const { cli, token } = await device();
  await cli(['login'], { email: freshEmail() });
  await db.$client`delete from sessions where token_hash = ${hashToken(await token())}`;
  expect((await cli(['whoami'])).code).toBe(3);
  expect((await cli(['settings', '--name', 'X'])).code).toBe(3);
});

test('agents log in with a login link from stdin', async () => {
  const email = freshEmail();
  await db.insert(users).values({ email, name: 'CLI test' });
  const link = `${url}/auth/verify?token=${await issueMagicLink(email)}`;
  const { cli } = await device();

  expect((await cli(['login', '--link', '-'], { stdin: `${link}\n` })).code).toBe(0);
  expect((await cli(['whoami', '--json'])).json()).toMatchObject({ user: { email } });

  const again = await device();
  expect(await again.cli(['login', '--link', link])).toMatchObject({ code: 1, err: de.linkExpired });
  expect(await again.cli(['login', '--link', 'https://example.com/'])).toMatchObject({ code: 2 });
});

test('the CLI creates no account past the closed sign-up', async () => {
  process.env.SIGNUP_OPEN = 'false';
  try {
    const email = freshEmail();
    const { cli } = await device();
    const before = mails().length;

    const login = await cli(['login', '--json'], { email });
    expect(login.code).toBe(1);
    expect(login.json()).toEqual({ error: de.signupClosed });
    expect(mails().length).toBe(before);

    // A link issued for an unknown address doesn't get past it either
    const link = `${url}/auth/verify?token=${await issueMagicLink(email)}`;
    expect(await cli(['login', '--link', link])).toMatchObject({ code: 1, err: de.signupClosed });
    expect(await db.$client`select id from users where email = ${email}`).toHaveLength(0);

    // TEAM_EMAILS allows first login even with closed sign-up
    const teamEmail = freshEmail();
    process.env.TEAM_EMAILS = ` ${teamEmail.toUpperCase()} `;
    expect((await cli(['login'], { email: teamEmail })).code).toBe(0);
    expect((await cli(['rides'])).code).toBe(0);

    // The allowlist lets the address in, as in the web
    process.env.SIGNUP_ALLOWLIST = email;
    expect((await cli(['login'], { email })).code).toBe(0);
  } finally {
    process.env.SIGNUP_OPEN = 'true';
    delete process.env.SIGNUP_ALLOWLIST;
    delete process.env.TEAM_EMAILS;
  }
});

test('the token only goes to the address it was issued for', async () => {
  const seen: (string | null)[] = [];
  const other = Bun.serve({
    port: 0,
    fetch: (req) => {
      seen.push(req.headers.get('authorization'));
      return Response.json({ error: 'nope' }, { status: 401 });
    },
  });
  try {
    const { cli } = await device();
    await cli(['login'], { email: freshEmail() });
    expect((await cli(['whoami', '--url', other.url.origin])).code).toBe(3);
    expect((await cli(['settings', '--name', 'X', '--url', other.url.origin])).code).toBe(3);
    expect(seen).toEqual([]);
    // The stored session stays for its own address, which later calls take without --url
    expect((await cli(['logout', '--url', other.url.origin])).code).toBe(0);
    expect((await cli(['whoami'])).code).toBe(0);
    expect((await cli(['whoami', '--json'], { raw: true })).json()).toMatchObject({
      user: { email: expect.any(String) },
    });
  } finally {
    await other.stop(true);
  }
});

test('help, wrong usage and an unreachable app', async () => {
  const { cli } = await device();
  const helpText = await cli([]);
  expect(helpText.code).toBe(0);
  expect(helpText.out).toContain(`${de.cliCommands}:`);
  expect(helpText.out).toContain('settings [--name <name>]');

  const english = await device({ LANG: 'en_US.UTF-8' });
  expect((await english.cli(['--help'])).out).toContain(`${messages.en.cliCommands}:`);
  expect((await cli(['--help', '--lang', 'en'])).out).toContain(`${messages.en.cliCommands}:`);

  expect((await cli(['whoami', '--help', '--json'])).json()).toMatchObject({
    commands: expect.arrayContaining([{ usage: 'whoami', text: de.cliWhoamiHelp }]),
    exitCodes: { loggedOut: 3 },
  });

  expect(await cli(['frobnicate'])).toMatchObject({ code: 2, err: de.cliUnknownCommand('frobnicate', SLUG) });
  expect((await cli(['frobnicate', '--json'])).json()).toEqual({ error: de.cliUnknownCommand('frobnicate', SLUG) });
  expect((await cli(['whoami', '--nope'])).code).toBe(2);
  expect(await cli(['login', '--email', 'a@example.com', '--url', 'http://127.0.0.1:1'])).toMatchObject({
    code: 1,
    err: de.cliUnreachable('http://127.0.0.1:1'),
  });
});

test('an unwritable config folder ends with an error, not a crash', async () => {
  const blocked = join(await mkdtemp(join(tmpdir(), 'cli-')), 'file');
  await Bun.write(blocked, '');
  const { cli } = await device({ LANG: 'de_DE.UTF-8', XDG_CONFIG_HOME: blocked });
  const login = await cli(['login', '--json'], { email: freshEmail() });
  expect(login.code).toBe(1);
  expect(login.json()).toEqual({ error: expect.any(String) });
});

test('the entry point passes the exit code to the shell', async () => {
  const env = { ...process.env, LC_ALL: 'en_US.UTF-8', XDG_CONFIG_HOME: await mkdtemp(join(tmpdir(), 'cli-')) };
  const main = join(import.meta.dir, 'main.ts');
  // Async, so the API in this process keeps answering
  const whoami = Bun.spawn(['bun', main, 'whoami', '--json', '--url', url], { env, stdout: 'pipe' });
  expect(await whoami.exited).toBe(3);
  expect(JSON.parse(await new Response(whoami.stdout).text())).toEqual({ error: messages.en.notLoggedIn });
  expect(await Bun.spawn(['bun', main, '--help'], { env, stdout: 'ignore' }).exited).toBe(0);
});
