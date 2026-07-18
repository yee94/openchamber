type CryptoSource = {
  randomUUID?: () => string;
  getRandomValues?: (bytes: Uint8Array) => Uint8Array;
};

const getCryptoSource = (): CryptoSource | null => {
  if (typeof globalThis.crypto === 'undefined') return null;
  return {
    randomUUID: typeof globalThis.crypto.randomUUID === 'function'
      ? () => globalThis.crypto.randomUUID()
      : undefined,
    getRandomValues: typeof globalThis.crypto.getRandomValues === 'function'
      ? (bytes) => globalThis.crypto.getRandomValues(bytes)
      : undefined,
  };
};

export const createUuid = (source: CryptoSource | null = getCryptoSource()): string => {
  try {
    const nativeUuid = source?.randomUUID?.();
    if (nativeUuid) return nativeUuid;
  } catch {
    // Continue with the WebView-compatible UUID v4 path.
  }

  const bytes = new Uint8Array(16);
  let hasSecureRandomBytes = false;
  try {
    if (source?.getRandomValues) {
      source.getRandomValues(bytes);
      hasSecureRandomBytes = true;
    }
  } catch {
    // Continue with the runtime fallback below.
  }

  if (!hasSecureRandomBytes) {
    for (let index = 0; index < bytes.length; index += 1) {
      bytes[index] = Math.floor(Math.random() * 256);
    }
  }

  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0'));
  return `${hex.slice(0, 4).join('')}-${hex.slice(4, 6).join('')}-${hex.slice(6, 8).join('')}-${hex.slice(8, 10).join('')}-${hex.slice(10).join('')}`;
};
