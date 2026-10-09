import type { Messages } from '@app/shared';
import { zValidator } from '@hono/zod-validator';
import type { ZodType } from 'zod';
import { t } from './i18n';

// Validates the JSON body and answers like every other error: { error: string }.
// Custom messages in the schemas are keys of the texts, zod's own are not.
export const validJson = <T extends ZodType>(schema: T) =>
  zValidator('json', schema, (result, c) => {
    if (!result.success) {
      const texts = t(c);
      const text = texts[result.error.issues[0]?.message as keyof Messages];
      return c.json({ error: typeof text === 'string' ? text : texts.invalidInput }, 400);
    }
  });
