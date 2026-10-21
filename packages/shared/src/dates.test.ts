import { expect, test } from 'bun:test';
import { addDays, today } from './index';

test('today is the date in Freiburg, not in UTC', () => {
  expect(today(new Date('2026-07-31T22:30:00Z'))).toBe('2026-08-01');
});

test('addDays counts dates, so the clock change costs no day', () => {
  // The night of 2026-10-25 is an hour longer, 2026-03-29 an hour shorter
  expect(addDays('2026-10-25', -7)).toBe('2026-10-18');
  expect(addDays('2026-03-29', -7)).toBe('2026-03-22');
  expect(addDays('2026-10-31', 1)).toBe('2026-11-01');
  expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
});
