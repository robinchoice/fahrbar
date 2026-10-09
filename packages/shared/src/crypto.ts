// End-to-end encryption of ride details with Web Crypto, in the browser and in Bun.
// The team holds one P-256 key pair. A booking encrypts to its public key with a
// fresh key pair per ride (ECDH, HKDF, AES-GCM), so the server only ever stores
// ciphertext. The private key lives on the server encrypted with the team
// passphrase (PBKDF2, AES-GCM) and is unlocked in the browser.

export type TeamKey = {
  publicKey: string;
  encryptedPrivateKey: string;
  salt: string;
  iv: string;
  iterations: number;
};

const ECDH = { name: 'ECDH', namedCurve: 'P-256' } as const;
const ITERATIONS = 600_000;
const INFO = new TextEncoder().encode('fahrbar ride v1');

const random = (length: number) => crypto.getRandomValues(new Uint8Array(length));

function toBase64(data: ArrayBuffer | Uint8Array) {
  let binary = '';
  for (const byte of new Uint8Array(data)) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function fromBase64(value: string) {
  return Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
}

async function passphraseKey(passphrase: string, salt: Uint8Array<ArrayBuffer>, iterations: number) {
  const base = await crypto.subtle.importKey('raw', new TextEncoder().encode(passphrase), 'PBKDF2', false, [
    'deriveKey',
  ]);
  return crypto.subtle.deriveKey(
    { name: 'PBKDF2', hash: 'SHA-256', salt, iterations },
    base,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt'],
  );
}

async function rideKey(privateKey: CryptoKey, publicKey: CryptoKey, salt: Uint8Array<ArrayBuffer>) {
  const shared = await crypto.subtle.deriveBits({ name: 'ECDH', public: publicKey }, privateKey, 256);
  const base = await crypto.subtle.importKey('raw', shared, 'HKDF', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'HKDF', hash: 'SHA-256', salt, info: INFO },
    base,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt'],
  );
}

export async function createTeamKey(passphrase: string): Promise<TeamKey> {
  const pair = await crypto.subtle.generateKey(ECDH, true, ['deriveBits']);
  const salt = random(16);
  const iv = random(12);
  const pkcs8 = await crypto.subtle.exportKey('pkcs8', pair.privateKey);
  const sealed = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    await passphraseKey(passphrase, salt, ITERATIONS),
    pkcs8,
  );
  return {
    publicKey: toBase64(await crypto.subtle.exportKey('raw', pair.publicKey)),
    encryptedPrivateKey: toBase64(sealed),
    salt: toBase64(salt),
    iv: toBase64(iv),
    iterations: ITERATIONS,
  };
}

// Throws on a wrong passphrase: AES-GCM refuses to decrypt
export async function unlockTeamKey(key: TeamKey, passphrase: string) {
  const pkcs8 = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: fromBase64(key.iv) },
    await passphraseKey(passphrase, fromBase64(key.salt), key.iterations),
    fromBase64(key.encryptedPrivateKey),
  );
  return crypto.subtle.importKey('pkcs8', pkcs8, ECDH, false, ['deriveBits']);
}

// v1.<ephemeral public key>.<iv>.<ciphertext>, the ephemeral key doubles as HKDF salt
export async function encryptRide(teamPublicKey: string, details: unknown) {
  const team = await crypto.subtle.importKey('raw', fromBase64(teamPublicKey), ECDH, false, []);
  const pair = await crypto.subtle.generateKey(ECDH, true, ['deriveBits']);
  const ephemeral = new Uint8Array(await crypto.subtle.exportKey('raw', pair.publicKey));
  const iv = random(12);
  const ciphertext = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    await rideKey(pair.privateKey, team, ephemeral),
    new TextEncoder().encode(JSON.stringify(details)),
  );
  return ['v1', toBase64(ephemeral), toBase64(iv), toBase64(ciphertext)].join('.');
}

export async function decryptRide(teamPrivateKey: CryptoKey, payload: string): Promise<unknown> {
  const [, ephemeral = '', iv = '', ciphertext = ''] = payload.split('.');
  const salt = fromBase64(ephemeral);
  const sender = await crypto.subtle.importKey('raw', salt, ECDH, false, []);
  const plain = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: fromBase64(iv) },
    await rideKey(teamPrivateKey, sender, salt),
    fromBase64(ciphertext),
  );
  return JSON.parse(new TextDecoder().decode(plain));
}
