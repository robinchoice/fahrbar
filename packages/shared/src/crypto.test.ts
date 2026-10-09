import { expect, test } from 'bun:test';
import { createTeamKey, decryptRide, encryptRide, unlockTeamKey } from './crypto';

// PBKDF2 with 600,000 rounds takes a moment
const SLOW = 30_000;
const details = { firstName: 'Helga', appointment: '08:30', street: 'Schwarzwaldstraße 91' };

test(
  'the team reads what a booking encrypted to its key',
  async () => {
    const key = await createTeamKey('correct horse battery staple');
    const payload = await encryptRide(key.publicKey, details);
    expect(payload).not.toContain('Helga');
    const privateKey = await unlockTeamKey(key, 'correct horse battery staple');
    expect(await decryptRide(privateKey, payload)).toEqual(details);
  },
  SLOW,
);

test(
  'a wrong passphrase does not unlock the key',
  async () => {
    const key = await createTeamKey('correct horse battery staple');
    await expect(unlockTeamKey(key, 'wrong')).rejects.toThrow();
  },
  SLOW,
);

test(
  'another team key cannot read the ride',
  async () => {
    const key = await createTeamKey('one');
    const other = await createTeamKey('two');
    const payload = await encryptRide(key.publicKey, details);
    await expect(decryptRide(await unlockTeamKey(other, 'two'), payload)).rejects.toThrow();
  },
  SLOW,
);
