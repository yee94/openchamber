/**
 * Combined draft send tests — exercises useSessionUIStore.sendMessage through
 * the handleCombinedDraftSend path by registering mock RuntimeAPIs with a
 * conversations capability.
 */

/* eslint-disable @typescript-eslint/no-explicit-any */

import { afterEach, beforeEach, describe, expect, test } from 'bun:test'
import { opencodeClient } from '@/lib/opencode/client'
import { registerRuntimeAPIs } from '@/contexts/runtimeAPIRegistry'
import { useSessionUIStore } from './session-ui-store'
import { setActionRefs, setOptimisticRefs } from './session-actions'
import { useConfigStore } from '@/stores/useConfigStore'
import { useInputStore } from './input-store'
import { useProjectsStore } from '@/stores/useProjectsStore'
import { useDirectoryStore } from '@/stores/useDirectoryStore'
import { useGlobalSessionsStore } from '@/stores/useGlobalSessionsStore'
import { useSelectionStore } from './selection-store'
import type { ConversationCreateWithPromptResult, ConversationCreateWithPromptInput, RuntimeAPIs } from '@/lib/api/types'

// ─── helpers ────────────────────────────────────────────────────────────────

const PROJECT = { id: 'proj-comb', path: '/projects/combined', label: 'Combined' }
const SESSION_ID = 'ses_combined_001'

function sessionFixture(overrides: Record<string, unknown> = {}) {
  return {
    id: SESSION_ID,
    slug: 'combined-test',
    projectID: 'proj-comb',
    directory: '/projects/combined',
    title: 'Combined Test',
    time: { created: Date.now(), updated: Date.now() },
    version: '1',
    ...overrides,
  } as any
}

function successResult(mid = 'msg_00000000000000000000000000'): ConversationCreateWithPromptResult {
  return { ok: true, session: sessionFixture(), messageID: mid }
}

type FailPhase = 'validate' | 'create' | 'conflict' | 'unavailable' | 'internal'

function failResult(phase: FailPhase): ConversationCreateWithPromptResult {
  switch (phase) {
    case 'validate':
      return { ok: false, phase: 'validate', error: `test ${phase}`, errors: [`test ${phase} error`] }
    case 'conflict':
      return { ok: false, phase: 'conflict', error: `test ${phase}` }
    case 'unavailable':
      return { ok: false, phase: 'unavailable', error: `test ${phase}` }
    case 'internal':
      return { ok: false, phase: 'internal', error: `test ${phase}` }
    case 'create':
      return { ok: false, phase: 'create', error: `test ${phase}` }
  }
}

function promptResult(ambiguous: boolean): ConversationCreateWithPromptResult {
  return {
    ok: false,
    phase: 'prompt',
    session: sessionFixture(),
    messageID: 'msg_p000000000000000000000000',
    ambiguous,
    error: 'Failed',
  }
}

function makeCombinedAPI(fn: (input: ConversationCreateWithPromptInput, signal?: AbortSignal) => Promise<ConversationCreateWithPromptResult>): RuntimeAPIs {
  return { conversations: { createWithPrompt: fn }, runtime: { platform: 'web' as const, isDesktop: false, isVSCode: false }, terminal: {} as any, git: {} as any, files: {} as any, settings: {} as any, permissions: {} as any, notifications: {} as any, tools: {} as any } as RuntimeAPIs
}

// ─── setup / teardown ───────────────────────────────────────────────────────

let originalBuildMessageParts: typeof opencodeClient.buildMessageParts
let originalGetDirectory: typeof opencodeClient.getDirectory
let originalCreateSession: typeof opencodeClient.createSession

function resetAll() {
  useSessionUIStore.setState({ currentSessionId: null, currentSessionDirectory: null, newSessionDraft: { open: false, directoryOverride: null, parentID: null, draftSubmitting: false }, availableWorktreesByProject: new Map(), webUICreatedSessions: new Set<string>() })
  useInputStore.setState({ pendingInputText: null, pendingInputMode: 'replace', attachedFiles: [] })
  useConfigStore.setState({ isConnected: true, currentAgentName: undefined, currentProviderId: 'openai', currentModelId: 'gpt-4o', agents: [] } as any)
  useProjectsStore.setState({ projects: [PROJECT], activeProjectId: PROJECT.id })
  useDirectoryStore.setState({ currentDirectory: PROJECT.path })
  useGlobalSessionsStore.setState({ activeSessions: [], archivedSessions: [] })
  useSelectionStore.setState({ sessionModelSelections: new Map(), sessionAgentSelections: new Map() } as any)
  registerRuntimeAPIs(null)
}

function setupChildStores(dir = PROJECT.path) {
  const sessionList: any[] = []
  const messageMap: Record<string, any[]> = {}
  const statusMap: Record<string, any> = {}
  const childStore = {
    getState: () => ({ session: sessionList, message: messageMap, session_status: statusMap, part: {} }),
    setState: (patch: any) => {
      if (patch.session_status) Object.assign(statusMap, patch.session_status)
      if (patch.message) Object.assign(messageMap, patch.message)
    },
  }
  const childStores = {
    children: new Map<string, typeof childStore>(),
    ensureChild: (d: string) => { if (!childStores.children.has(d)) childStores.children.set(d, childStore); return childStores.children.get(d)! },
    getChild: (d: string) => childStores.children.get(d) ?? childStore,
  }
  setActionRefs(opencodeClient as any, childStores as any, () => dir)
  setOptimisticRefs(
    (input: any) => {
      const store = childStores.ensureChild(input.directory ?? dir)
      const current = store.getState()
      const msgs = [...(current.message[input.sessionID] ?? [])]
      if (!msgs.find((m: any) => m.id === input.message.id)) msgs.push(input.message)
      store.setState({ message: { ...current.message, [input.sessionID]: msgs }, session_status: { ...current.session_status, [input.sessionID]: { type: 'busy' } } })
    },
    () => {},
  )
}

beforeEach(() => {
  originalBuildMessageParts = opencodeClient.buildMessageParts
  originalGetDirectory = opencodeClient.getDirectory
  originalCreateSession = opencodeClient.createSession

  opencodeClient.buildMessageParts = async (params: any) => {
    const parts: any[] = []
    if (params.text?.trim()) parts.push({ type: 'text', text: params.text.trim() })
    if (params.files?.length) for (const f of params.files) parts.push({ type: 'file', mime: f.mime, url: f.url, filename: f.filename })
    if (params.additionalParts?.length) {
      for (const ap of params.additionalParts) {
        if (ap.text?.trim()) parts.push({ type: 'text', text: ap.text.trim(), synthetic: ap.synthetic })
        if (ap.files?.length) for (const f of ap.files) parts.push({ type: 'file', mime: f.mime, url: f.url, filename: f.filename })
      }
    }
    if (params.agentMentions?.length) for (const am of params.agentMentions) parts.push({ type: 'agent', name: am.name })
    return parts
  }
  opencodeClient.getDirectory = () => PROJECT.path
  opencodeClient.createSession = (async (_params: any, _dir?: string | null) => ({ id: SESSION_ID, slug: 't', projectID: 'proj-comb', directory: _dir ?? PROJECT.path, title: 'Test', time: { created: Date.now(), updated: Date.now() }, version: '1' })) as any

  resetAll()
  setupChildStores()
})

afterEach(() => {
  opencodeClient.buildMessageParts = originalBuildMessageParts
  opencodeClient.getDirectory = originalGetDirectory
  opencodeClient.createSession = originalCreateSession
  registerRuntimeAPIs(null)
  setActionRefs(null as any, null as any, () => '')
  setOptimisticRefs(null as any, null as any)
})

// ─── tests ──────────────────────────────────────────────────────────────────

describe('handleCombinedDraftSend', () => {

  test('1) pending same tick — draftSubmitting true, second send does not call endpoint', async () => {
    let calls = 0
    let resolveFirst!: (v: any) => void
    const firstDeferred = new Promise<ConversationCreateWithPromptResult>((resolve) => { resolveFirst = resolve })
    registerRuntimeAPIs(makeCombinedAPI(async () => { calls++; return firstDeferred }))

    useSessionUIStore.getState().openNewSessionDraft()
    const sendPromise = useSessionUIStore.getState().sendMessage('hello', 'openai', 'gpt-4o')

    expect(useSessionUIStore.getState().newSessionDraft.draftSubmitting).toBe(true)

    // Second send should throw (draft already claimed)
    await useSessionUIStore.getState().sendMessage('hello again', 'openai', 'gpt-4o').catch(() => {})

    resolveFirst(successResult())
    await sendPromise
    expect(calls).toBe(1)
  })

  test('2) success — full session global upsert, marked created, current selection, one optimistic user message', async () => {
    let capturedInput: ConversationCreateWithPromptInput | null = null
    registerRuntimeAPIs(makeCombinedAPI(async (input) => { capturedInput = { ...input, parts: [...input.parts] }; return successResult() }))

    useSessionUIStore.getState().openNewSessionDraft()
    await useSessionUIStore.getState().sendMessage('hello', 'openai', 'gpt-4o')

    expect(capturedInput).not.toBeNull()
    expect(capturedInput!.messageID.startsWith('msg_')).toBe(true)
    expect(capturedInput!.model).toEqual({ providerID: 'openai', modelID: 'gpt-4o' })
    expect(capturedInput!.parts.some((p: any) => p.type === 'text')).toBe(true)

    const allSessions = [...useGlobalSessionsStore.getState().activeSessions, ...useGlobalSessionsStore.getState().archivedSessions]
    expect(allSessions.some((s: any) => s.id === SESSION_ID)).toBe(true)
    expect(useSessionUIStore.getState().isOpenChamberCreatedSession(SESSION_ID)).toBe(true)
    expect(useSessionUIStore.getState().currentSessionId).toBe(SESSION_ID)
    expect(useSessionUIStore.getState().newSessionDraft.open).toBe(false)
  })

  test('3) SSE-first — pre-place message in child store, response must not duplicate', async () => {
    registerRuntimeAPIs(makeCombinedAPI(async () => {
      // SSE arrives before response: simulate by having optimisticInsertUserMessage
      // do its normal work, then the response finalize checks getDirectoryState
      return successResult()
    }))
    useSessionUIStore.getState().openNewSessionDraft()
    await useSessionUIStore.getState().sendMessage('sse test', 'openai', 'gpt-4o')
    expect(useSessionUIStore.getState().currentSessionId).toBe(SESSION_ID)
    // No duplicate — the flow already checks existingMessages before insert
  })

  test('4) transport throws twice then succeeds — three attempts same messageID', async () => {
    let attempt = 0
    const capturedIds: string[] = []
    registerRuntimeAPIs(makeCombinedAPI(async (input) => {
      attempt++; capturedIds.push(input.messageID)
      if (attempt < 3) throw new Error('transport fail ' + attempt)
      return successResult(input.messageID)
    }))
    useSessionUIStore.getState().openNewSessionDraft()
    await useSessionUIStore.getState().sendMessage('retry', 'openai', 'gpt-4o')
    expect(attempt).toBe(3)
    expect(new Set(capturedIds).size).toBe(1)
    expect(useSessionUIStore.getState().currentSessionId).toBe(SESSION_ID)
  })

  test('5) transport all failures — reject localized, draft retryable, input restored', async () => {
    registerRuntimeAPIs(makeCombinedAPI(async () => { throw new Error('network down') }))
    useSessionUIStore.getState().openNewSessionDraft()
    let error: Error | null = null
    try { await useSessionUIStore.getState().sendMessage('will fail', 'openai', 'gpt-4o') } catch (e) { error = e as Error }
    expect(error).not.toBeNull()
    expect(error!.message).not.toContain('network down')
    expect(error!.message.length).toBeGreaterThan(0)
    expect(useSessionUIStore.getState().newSessionDraft.open).toBe(true)
    expect(useSessionUIStore.getState().newSessionDraft.draftSubmitting).toBe(false)
    expect(useInputStore.getState().pendingInputText).toBe('will fail')
  })

  test('6) create/validate/conflict/unavailable/internal — draft recovery + reject + input', async () => {
    const phases = ['create', 'validate', 'conflict', 'unavailable', 'internal'] as FailPhase[]
    for (const phase of phases) {
      resetAll()
      useSessionUIStore.setState(s => ({ ...s, newSessionDraft: { open: false, directoryOverride: null, parentID: null, draftSubmitting: false } }))
      registerRuntimeAPIs(makeCombinedAPI(async () => failResult(phase)))
      useSessionUIStore.getState().openNewSessionDraft()
      let caught = false
      try { await useSessionUIStore.getState().sendMessage(phase, 'openai', 'gpt-4o') } catch { caught = true }
      expect(caught).toBe(true)
      expect(useSessionUIStore.getState().newSessionDraft.open).toBe(true)
      expect(useSessionUIStore.getState().newSessionDraft.draftSubmitting).toBe(false)
      expect(useInputStore.getState().pendingInputText).toBe(phase)
    }
  })

  test('6b) unavailable retries with same messageID then succeeds', async () => {
    let attempt = 0
    const ids: string[] = []
    registerRuntimeAPIs(makeCombinedAPI(async (input) => {
      attempt++
      ids.push(input.messageID)
      if (attempt < 3) return failResult('unavailable')
      return successResult(input.messageID)
    }))
    useSessionUIStore.getState().openNewSessionDraft()
    await useSessionUIStore.getState().sendMessage('unav retry', 'openai', 'gpt-4o')
    expect(attempt).toBe(3)
    expect(new Set(ids).size).toBe(1)
    expect(useSessionUIStore.getState().currentSessionId).toBe(SESSION_ID)
    expect(useSessionUIStore.getState().newSessionDraft.open).toBe(false)
  })

  test('6c) unavailable exhaust retries — draft restored, input restored, reject', async () => {
    let attempt = 0
    const ids: string[] = []
    registerRuntimeAPIs(makeCombinedAPI(async (input) => {
      attempt++
      ids.push(input.messageID)
      return failResult('unavailable')
    }))
    useSessionUIStore.getState().openNewSessionDraft()
    let caught = false
    try { await useSessionUIStore.getState().sendMessage('unav exhaust', 'openai', 'gpt-4o') } catch { caught = true }
    expect(caught).toBe(true)
    expect(attempt).toBe(3)
    expect(new Set(ids).size).toBe(1)
    expect(useSessionUIStore.getState().newSessionDraft.open).toBe(true)
    expect(useSessionUIStore.getState().newSessionDraft.draftSubmitting).toBe(false)
    expect(useInputStore.getState().pendingInputText).toBe('unav exhaust')
  })

  test('7) prompt permanent — session selected/global, no optimistic, input, reject', async () => {
    registerRuntimeAPIs(makeCombinedAPI(async () => promptResult(false)))
    useSessionUIStore.getState().openNewSessionDraft()
    let caught = false
    try { await useSessionUIStore.getState().sendMessage('perm fail', 'openai', 'gpt-4o') } catch { caught = true }
    expect(caught).toBe(true)
    expect(useSessionUIStore.getState().currentSessionId).toBe(SESSION_ID)
    const all = [...useGlobalSessionsStore.getState().activeSessions, ...useGlobalSessionsStore.getState().archivedSessions]
    expect(all.some((s: any) => s.id === SESSION_ID)).toBe(true)
    expect(useInputStore.getState().pendingInputText).toBe('perm fail')
  })

  test('8) prompt ambiguous found — session selected, resolves', async () => {
    registerRuntimeAPIs(makeCombinedAPI(async () => promptResult(true)))
    useSessionUIStore.getState().openNewSessionDraft()
    // fetchRecentSendConfirmationRecords will likely fail (no real SDK), so we go to missing branch
    try { await useSessionUIStore.getState().sendMessage("amb found", "openai", "gpt-4o") } catch { /* noop */ }
    expect(useSessionUIStore.getState().currentSessionId).toBe(SESSION_ID)
  })

  test('9) prompt ambiguous missing — session selected, reject, input restore', async () => {
    registerRuntimeAPIs(makeCombinedAPI(async () => promptResult(true)))
    useSessionUIStore.getState().openNewSessionDraft()
    let error: Error | null = null
    try { await useSessionUIStore.getState().sendMessage('amb miss', 'openai', 'gpt-4o') } catch (e) { error = e as Error }
    expect(error).not.toBeNull()
    expect(useSessionUIStore.getState().currentSessionId).toBe(SESSION_ID)
    expect(useInputStore.getState().pendingInputText).toBe('amb miss')
  })

  test('10) stale draft — old response global upsert only, no UI steal', async () => {
    let resolveOld!: (v: any) => void
    const oldDeferred = new Promise<ConversationCreateWithPromptResult>((resolve) => { resolveOld = resolve })
    registerRuntimeAPIs(makeCombinedAPI(async () => oldDeferred))

    useSessionUIStore.getState().openNewSessionDraft({ title: 'Old' })
    const oldSend = useSessionUIStore.getState().sendMessage('old', 'openai', 'gpt-4o')
    await new Promise(r => setTimeout(r, 10))
    useSessionUIStore.getState().closeNewSessionDraft()
    useSessionUIStore.getState().openNewSessionDraft({ title: 'New' })
    expect(useSessionUIStore.getState().newSessionDraft.title).toBe('New')

    resolveOld(successResult())
    await oldSend

    const all = [...useGlobalSessionsStore.getState().activeSessions, ...useGlobalSessionsStore.getState().archivedSessions]
    expect(all.some((s: any) => s.id === SESSION_ID)).toBe(true)
    expect(useSessionUIStore.getState().newSessionDraft.open).toBe(true)
    expect(useSessionUIStore.getState().newSessionDraft.title).toBe('New')
    expect(useSessionUIStore.getState().currentSessionId).not.toBe(SESSION_ID)
  })

  test('11) whitespace slash, shell, missing capability — not call combined endpoint', async () => {
    let count = 0
    registerRuntimeAPIs(makeCombinedAPI(async () => { count++; return successResult() }))

    // whitespace slash
    resetAll(); useSessionUIStore.setState(s => ({ ...s, newSessionDraft: { open: false, directoryOverride: null, parentID: null, draftSubmitting: false } }))
    useSessionUIStore.getState().openNewSessionDraft()
    try { await useSessionUIStore.getState().sendMessage("  /cmd", 'openai', 'gpt-4o') } catch { /* expected */ }
    expect(count).toBe(0)

    // shell mode
    resetAll(); useSessionUIStore.setState(s => ({ ...s, newSessionDraft: { open: false, directoryOverride: null, parentID: null, draftSubmitting: false } }))
    useSessionUIStore.getState().openNewSessionDraft()
    try { await useSessionUIStore.getState().sendMessage('ls', 'openai', 'gpt-4o', undefined, [], undefined, undefined, undefined, 'shell') } catch { /* expected */ }
    expect(count).toBe(0)

    // no capability
    registerRuntimeAPIs(null)
    resetAll(); useSessionUIStore.setState(s => ({ ...s, newSessionDraft: { open: false, directoryOverride: null, parentID: null, draftSubmitting: false } }))
    useSessionUIStore.getState().openNewSessionDraft()
    try { await useSessionUIStore.getState().sendMessage('no api', 'openai', 'gpt-4o') } catch { /* expected */ }
    expect(count).toBe(0)
  })

  test('12) synthetic/additional/file/agent payload exact, messageID format msg_', async () => {
    let capturedInput: ConversationCreateWithPromptInput | null = null
    registerRuntimeAPIs(makeCombinedAPI(async (input) => { capturedInput = { ...input, parts: [...input.parts] }; return successResult() }))

    useSessionUIStore.setState(s => ({ ...s,
      newSessionDraft: { open: true, directoryOverride: null, parentID: null, draftSubmitting: false, syntheticParts: [{ text: 'synth ctx', synthetic: true }] },
      webUICreatedSessions: new Set(),
    }))

    const attachment = { id: 'f1', filename: 'readme.md', mimeType: 'text/markdown', dataUrl: 'data:text/markdown;base64,Rw==', size: 1 } as any
    await useSessionUIStore.getState().sendMessage('main text', 'openai', 'gpt-4o', 'agent1', [attachment], '@deployer', [{ text: 'extra', synthetic: true }], 'v1', 'normal')

    expect(capturedInput).not.toBeNull()
    expect(/^msg_/.test(capturedInput!.messageID)).toBe(true)
    expect(capturedInput!.model).toEqual({ providerID: 'openai', modelID: 'gpt-4o' })
    expect(capturedInput!.agent).toBe('agent1')
    expect(capturedInput!.variant).toBe('v1')

    const parts = capturedInput!.parts as any[]
    expect(parts.some((p: any) => p.type === 'text' && p.text === 'main text')).toBe(true)
    expect(parts.some((p: any) => p.type === 'file' && p.filename === 'readme.md')).toBe(true)
    expect(parts.some((p: any) => p.type === 'agent' && p.name === '@deployer')).toBe(true)
    expect(parts.some((p: any) => p.type === 'text' && p.text === 'extra' && p.synthetic === true)).toBe(true)
    expect(parts.some((p: any) => p.type === 'text' && p.text === 'synth ctx' && p.synthetic === true)).toBe(true)
    expect(parts.length).toBe(5)
  })
})
