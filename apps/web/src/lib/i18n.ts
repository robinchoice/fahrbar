import { type Locale, messages } from '@app/shared';
import { invalidateAll } from '$app/navigation';
import { page } from '$app/state';

// Texts in the current language, e.g. {t().save}. hooks.server.ts takes the
// language from the cookie, else from the browser.
export const t = () => messages[page.data.locale];

export async function setLocale(locale: Locale) {
  // biome-ignore lint/suspicious/noDocumentCookie: cookieStore needs HTTPS, dev over a LAN address has none
  document.cookie = `locale=${locale}; path=/; max-age=31536000; samesite=lax`;
  await invalidateAll();
  document.documentElement.lang = locale;
}
