// The unlocked team key. It lives in this tab's memory only, a reload asks for the passphrase again.
export const teamKey = $state({ key: null as CryptoKey | null });
