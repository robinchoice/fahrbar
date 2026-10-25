import { z } from 'zod';
import { type Command, EXIT, Failure, str } from '../command';
import { currentUser, userSchema } from './auth';

export const settings: Command = {
  help: (m) => [['settings [--name <name>]', m.cliSettingsHelp]],
  options: { name: { type: 'string' } },
  async run(ctx) {
    const { values, m, api, session } = ctx;
    const name = str(values.name);
    if (!session) throw new Failure(m.notLoggedIn, EXIT.loggedOut);
    const user =
      name === undefined
        ? await currentUser(ctx)
        : (await api.patch('/auth/me', z.object({ user: userSchema }), { name })).user;
    return {
      data: { user },
      text: [`${m.cliDisplayName}: ${user.name}`, `${m.email}: ${user.email}`].join('\n'),
    };
  },
};
