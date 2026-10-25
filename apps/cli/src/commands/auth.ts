import { z } from 'zod';
import { type Command, type Context, EXIT, Failure, str } from '../command';
import { removeSession, saveSession } from '../config';

export const userSchema = z.object({
  id: z.string(),
  email: z.string(),
  name: z.string(),
  admin: z.boolean(),
});
const meSchema = z.object({ user: userSchema.nullable() });
const loginSchema = z.object({ user: userSchema, token: z.string() });
const okSchema = z.object({ ok: z.literal(true) });

// The logged-in account, for every command that needs one
export async function currentUser({ api, session, m }: Context) {
  const user = session && (await api.get('/auth/me', meSchema)).user;
  if (!user) throw new Failure(m.notLoggedIn, EXIT.loggedOut);
  return user;
}

// Like the app: a code by mail. The API enforces the closed sign-up.
async function withCode({ api, values, io, m }: Context) {
  const email = str(values.email) ?? (await io.ask(m.cliAskEmail)).trim();
  await api.post('/auth/code', okSchema, { email });
  io.err(m.cliCodeSent(email));
  const code = (await io.ask(m.cliAskCode)).trim();
  return api.post('/auth/code/verify', loginSchema, { email, code });
}

// A login link from the mail or from the Kontor's login-link (README, „CLI“)
async function withLink({ api, io, m }: Context, link: string) {
  const text = link === '-' ? await io.stdin() : link;
  const token = URL.parse(text.trim())?.searchParams.get('token');
  if (!token) throw new Failure(m.linkIncomplete, EXIT.usage);
  return api.post('/auth/verify', loginSchema, { token, cookie: false });
}

export const auth: Record<string, Command> = {
  login: {
    help: (m) => [
      ['login [--email <email>]', m.cliLoginHelp],
      ['login --link <link>|-', m.cliLinkHelp],
    ],
    options: { email: { type: 'string' }, link: { type: 'string' } },
    async run(ctx) {
      // A new login replaces the token of this device: the old one is revoked first, so none stays valid unseen
      if (ctx.session) {
        await ctx.api.post('/auth/logout', okSchema);
        await removeSession(ctx.io.env);
      }
      const link = str(ctx.values.link);
      const { user, token } = link === undefined ? await withCode(ctx) : await withLink(ctx, link);
      await saveSession(ctx.io.env, { url: ctx.url, token });
      return { data: { user }, text: ctx.m.cliLoggedIn(user.email) };
    },
  },

  whoami: {
    help: (m) => [['whoami', m.cliWhoamiHelp]],
    async run(ctx) {
      const user = await currentUser(ctx);
      return { data: { user }, text: `${user.name} <${user.email}>${user.admin ? ' · Admin' : ''}` };
    },
  },

  logout: {
    help: (m) => [['logout', m.cliLogoutHelp]],
    async run({ api, session, io, m }) {
      if (session) {
        await api.post('/auth/logout', okSchema);
        await removeSession(io.env);
      }
      return { data: { ok: true }, text: m.cliLoggedOut };
    },
  },
};
