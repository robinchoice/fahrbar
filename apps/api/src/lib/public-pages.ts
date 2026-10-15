import type { Database } from '@app/db';
import { APP_NAME, type Messages, PRICE } from '@app/shared';

// A page anyone sees without logging in. Agents get it as <path>.md, listed in
// llms.txt and joined in llms-full.txt (routes/agents.ts). body is Markdown
// below the title and description and carries the page's content, not its
// layout. path is the page's URL, so the browser test can open it.
export type PublicPage = { path: string; title: string; description: string; body?: string };

// Every public page with its own content, in the given language. Never
// anything behind the login, no accounts, no user data, no admin pages.
// Booking links of practices and patients' ride links stay out: they are
// handed out personally, not published.
export async function publicPages(_db: Database, m: Messages): Promise<PublicPage[]> {
  return [
    {
      path: '/',
      title: APP_NAME,
      description: m.tagline,
      body: [
        m.homeLead,
        [m.homeStep1, m.homeStep2, m.homeStep3(PRICE)].map((step, i) => `${i + 1}. ${step}`).join('\n'),
        m.encryptedNote,
        `${m.homePilot} [${m.sourceCode}](https://github.com/robinchoice/fahrbar)`,
      ].join('\n\n'),
    },
  ];
}
