import { messages, pickLocale } from '@app/shared';
import type { Context } from 'hono';

// Texts in the language the client asks for. Web and app send the chosen one as Accept-Language.
export const t = (c: Context) => messages[pickLocale(c.req.header('accept-language'))];
