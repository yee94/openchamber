import { afterEach, describe, expect, test } from 'bun:test';

import { readStoredLocaleForBootstrap } from './bootstrap';
import { detectInitialLocale, LOCALE_STORAGE_KEY, normalizeLocale } from './runtime';
import { initializeLocale } from './store';

const originalNavigator = globalThis.navigator;
const originalWindow = globalThis.window;

const installWebEnvironment = ({
  languages,
  language,
  storedLocale,
}: {
  languages: readonly string[];
  language: string;
  storedLocale?: string;
}) => {
  const storage = new Map<string, string>();
  if (storedLocale) {
    storage.set(LOCALE_STORAGE_KEY, JSON.stringify({ locale: storedLocale }));
  }

  Object.defineProperty(globalThis, 'navigator', {
    configurable: true,
    value: { languages, language },
  });
  Object.defineProperty(globalThis, 'window', {
    configurable: true,
    value: {
      localStorage: {
        getItem: (key: string) => storage.get(key) ?? null,
        setItem: (key: string, value: string) => { storage.set(key, value); },
      },
    },
  });

  return storage;
};

afterEach(() => {
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: originalNavigator });
  Object.defineProperty(globalThis, 'window', { configurable: true, value: originalWindow });
});

describe('i18n locale detection', () => {
  test('uses the first supported language exposed by the web platform', () => {
    installWebEnvironment({ languages: ['de-DE', 'zh-Hant-HK', 'fr-FR'], language: 'de-DE' });

    expect(detectInitialLocale()).toBe('zh-TW');
  });

  test('uses navigator.language when the language list is empty', () => {
    installWebEnvironment({ languages: [], language: 'ja-JP' });

    expect(detectInitialLocale()).toBe('ja');
  });

  test('keeps an explicit stored locale ahead of the system locale', () => {
    installWebEnvironment({ languages: ['zh-CN'], language: 'zh-CN', storedLocale: 'fr' });

    expect(detectInitialLocale()).toBe('fr');
  });

  test('uses the same system locale for bootstrap messages', () => {
    installWebEnvironment({ languages: ['pt-PT'], language: 'pt-PT' });

    expect(readStoredLocaleForBootstrap()).toBe('pt-BR');
  });

  test('keeps an automatically detected locale linked to system preferences', () => {
    const storage = installWebEnvironment({ languages: ['ja-JP'], language: 'ja-JP' });

    initializeLocale();

    expect(storage.has(LOCALE_STORAGE_KEY)).toBe(false);
  });

  test('maps traditional Chinese web locales to the supported locale', () => {
    expect(normalizeLocale('zh-HK')).toBe('zh-TW');
    expect(normalizeLocale('zh-MO')).toBe('zh-TW');
    expect(normalizeLocale('zh-Hant')).toBe('zh-TW');
  });
});
