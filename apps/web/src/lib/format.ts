import type { Locale } from '@app/shared';

// Dates of mornings are plain YYYY-MM-DD in Freiburg, formatted without shifting time zones
export function formatDate(date: string, locale: Locale, length: 'long' | 'short' = 'long') {
  return new Intl.DateTimeFormat(locale, {
    weekday: length,
    day: 'numeric',
    month: length,
    timeZone: 'UTC',
  }).format(new Date(`${date}T00:00:00Z`));
}
