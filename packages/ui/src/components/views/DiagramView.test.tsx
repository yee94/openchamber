import { describe, expect, mock, test } from 'bun:test';

type Component = (props: Record<string, unknown>) => unknown;
type HookRecord = {
  values: unknown[];
  deps: Array<unknown[] | undefined>;
  cleanups: Array<(() => void) | undefined>;
};

const hookRecords = new Map<unknown, HookRecord>();
let currentRecord: HookRecord | null = null;
let hookIndex = 0;
let pendingEffects: Array<() => void> = [];
let stateUpdates = 0;
let pendingDiagramFile: string | null = null;
let readFile: (path: string) => Promise<{ content: string }> = async () => ({ content: '' });
let writeFile: (path: string, content: string) => Promise<void> = async () => undefined;
let editorXml = '';

const shallowEqualDeps = (left?: unknown[], right?: unknown[]): boolean => (
  Boolean(left && right)
  && left!.length === right!.length
  && left!.every((value, index) => Object.is(value, right![index]))
);

const getHookRecord = (): HookRecord => {
  if (!currentRecord) throw new Error('Hooks can only run during a render pass');
  return currentRecord;
};

const renderComponent = (component: Component, props: Record<string, unknown> = {}): unknown => {
  const previousRecord = currentRecord;
  const previousHookIndex = hookIndex;
  currentRecord = hookRecords.get(component) ?? { values: [], deps: [], cleanups: [] };
  hookRecords.set(component, currentRecord);
  hookIndex = 0;
  try {
    return component(props);
  } finally {
    currentRecord = previousRecord;
    hookIndex = previousHookIndex;
  }
};

function useState<T>(initialValue: T): readonly [T, (value: T) => void] {
  const record = getHookRecord();
  const index = hookIndex++;
  if (record.values[index] === undefined) record.values[index] = initialValue;
  return [record.values[index] as T, (value: T) => {
    stateUpdates += 1;
    record.values[index] = value;
  }] as const;
}

function useRef<T>(initialValue: T): { current: T } {
  const record = getHookRecord();
  const index = hookIndex++;
  if (record.values[index] === undefined) record.values[index] = { current: initialValue };
  return record.values[index] as { current: T };
}

function useCallback<T>(callback: T, deps: unknown[]): T {
  const record = getHookRecord();
  const index = hookIndex++;
  if (!shallowEqualDeps(record.deps[index], deps)) {
    record.values[index] = callback;
    record.deps[index] = deps;
  }
  return record.values[index] as T;
}

function useEffect(effect: () => void | (() => void), deps: unknown[]): void {
  const record = getHookRecord();
  const index = hookIndex++;
  if (!shallowEqualDeps(record.deps[index], deps)) {
    record.deps[index] = deps;
    pendingEffects.push(() => {
      record.cleanups[index] = effect() ?? undefined;
    });
  }
}

const jsx = (type: Component | string, props: Record<string, unknown>): unknown => (
  typeof type === 'function' ? renderComponent(type, props) : { type, props }
);

const ReactMock = { useState, useRef, useCallback, useEffect };
mock.module('react', () => ({ __esModule: true, default: ReactMock, ...ReactMock }));
mock.module('react/jsx-runtime', () => ({ Fragment: Symbol('Fragment'), jsx, jsxs: jsx, jsxDEV: jsx }));
mock.module('react/jsx-dev-runtime', () => ({ Fragment: Symbol('Fragment'), jsx, jsxs: jsx, jsxDEV: jsx }));
mock.module('@/components/diagram', () => ({
  DiagramEditor: (props: Record<string, unknown>) => {
    const ref = props.ref as { current: { getXml: () => string } | null } | undefined;
    if (ref) ref.current = { getXml: () => editorXml };
    return { type: 'diagram-editor', props };
  },
}));
mock.module('@/components/icon/Icon', () => ({ Icon: () => null }));
mock.module('@/hooks/useRuntimeAPIs', () => ({ useRuntimeAPIs: () => ({ files: { readFile, writeFile } }) }));
mock.module('@/lib/i18n', () => ({ useI18n: () => ({ t: (key: string) => key }) }));
mock.module('@/stores/useUIStore', () => {
  const store = (selector: (state: { pendingDiagramFile: string | null }) => unknown) => selector({ pendingDiagramFile });
  store.getState = () => ({
    consumePendingDiagramFile: () => {
      const pending = pendingDiagramFile;
      pendingDiagramFile = null;
      return pending;
    },
    setActiveMainTab: () => undefined,
  });
  return { useUIStore: store };
});

const { DiagramView } = await import('./DiagramView');

const flushEffects = () => {
  const effects = pendingEffects;
  pendingEffects = [];
  effects.forEach((effect) => effect());
};

const cleanup = () => {
  for (const record of hookRecords.values()) record.cleanups.forEach((effect) => effect?.());
};

const resetHarness = () => {
  hookRecords.clear();
  currentRecord = null;
  hookIndex = 0;
  pendingEffects = [];
  stateUpdates = 0;
  pendingDiagramFile = null;
  readFile = async () => ({ content: '' });
  writeFile = async () => undefined;
  editorXml = '';
};

const deferred = <T,>() => {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((resolvePromise) => {
    resolve = resolvePromise;
  });
  return { promise, resolve };
};

const getEditorXml = (node: unknown): string | undefined => {
  if (!node || typeof node !== 'object') return undefined;
  const element = node as { type?: string; props?: { xml?: string; children?: unknown } };
  if (element.type === 'diagram-editor') return element.props?.xml;
  const children = element.props?.children;
  if (Array.isArray(children)) return children.map(getEditorXml).find((xml) => xml !== undefined);
  return getEditorXml(children);
};

const getSaveButton = (node: unknown): { onClick?: () => void } | undefined => {
  if (!node || typeof node !== 'object') return undefined;
  const element = node as { type?: string; props?: { title?: string; onClick?: () => void; children?: unknown } };
  if (element.type === 'button' && element.props?.title === 'filesView.diagram.saveDiagram') return element.props;
  const children = element.props?.children;
  if (Array.isArray(children)) return children.map(getSaveButton).find((button) => button !== undefined);
  return getSaveButton(children);
};

describe('DiagramView file loading', () => {
  test('keeps the latest diagram content when an earlier read resolves last', async () => {
    resetHarness();
    const first = deferred<{ content: string }>();
    const second = deferred<{ content: string }>();
    readFile = (path) => path === '/first.drawio' ? first.promise : second.promise;

    pendingDiagramFile = '/first.drawio';
    renderComponent(DiagramView);
    flushEffects();

    pendingDiagramFile = '/second.drawio';
    renderComponent(DiagramView);
    flushEffects();

    second.resolve({ content: '<second />' });
    await Promise.resolve();
    await Promise.resolve();
    expect(getEditorXml(renderComponent(DiagramView))).toBe('<second />');

    first.resolve({ content: '<first />' });
    await Promise.resolve();
    await Promise.resolve();
    expect(getEditorXml(renderComponent(DiagramView))).toBe('<second />');
  });

  test('avoids state updates after unmount while a read is pending', async () => {
    resetHarness();
    const request = deferred<{ content: string }>();
    readFile = () => request.promise;

    pendingDiagramFile = '/diagram.drawio';
    renderComponent(DiagramView);
    flushEffects();
    stateUpdates = 0;
    cleanup();

    request.resolve({ content: '<diagram />' });
    await Promise.resolve();
    await Promise.resolve();
    expect(stateUpdates).toBe(0);
  });

  test('keeps the active diagram content when a previous file save resolves after switching files', async () => {
    resetHarness();
    const save = deferred<void>();
    readFile = async (path) => ({ content: path === '/a.drawio' ? '<a />' : '<b />' });
    writeFile = (path) => {
      expect(path).toBe('/a.drawio');
      return save.promise;
    };

    pendingDiagramFile = '/a.drawio';
    renderComponent(DiagramView);
    flushEffects();
    await Promise.resolve();
    await Promise.resolve();
    editorXml = '<a saved />';
    getSaveButton(renderComponent(DiagramView))?.onClick?.();
    await Promise.resolve();

    pendingDiagramFile = '/b.drawio';
    renderComponent(DiagramView);
    flushEffects();
    await Promise.resolve();
    await Promise.resolve();
    expect(getEditorXml(renderComponent(DiagramView))).toBe('<b />');

    save.resolve();
    await Promise.resolve();
    await Promise.resolve();
    expect(getEditorXml(renderComponent(DiagramView))).toBe('<b />');
  });
});
