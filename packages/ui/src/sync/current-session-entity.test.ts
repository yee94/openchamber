import { describe, expect, test } from 'bun:test'

import { resolveCurrentSessionEntity, resolveParentSessionTarget } from './current-session-entity'

type Session = {
  id: string
  title?: string | null
  parentID?: string | null
  directory?: string | null
}

describe('resolveCurrentSessionEntity', () => {
  test('prefers the cross-directory live session', () => {
    const live: Session = { id: 'ses_current', title: 'Live title' }
    const global: Session = { id: 'ses_current', title: 'Global title' }

    expect(resolveCurrentSessionEntity('ses_current', live, global)).toBe(live)
  })

  test('falls back to a global active session beyond the collapsed page boundary', () => {
    const globalSessions: Session[] = Array.from({ length: 21 }, (_, index) => ({
      id: `ses_${index + 1}`,
      title: `Session ${index + 1}`,
    }))
    const global = globalSessions[20]

    expect(resolveCurrentSessionEntity('ses_21', null, global)).toBe(global)
  })

  test('keeps a live entity with a blank title ahead of global metadata', () => {
    const live: Session = { id: 'ses_current', title: '  ' }
    const global: Session = { id: 'ses_current', title: 'Global title' }

    expect(resolveCurrentSessionEntity('ses_current', live, global)).toBe(live)
  })

  test('uses a matching global entity when the live candidate has another ID', () => {
    const global: Session = { id: 'ses_current', title: 'Global title' }

    expect(resolveCurrentSessionEntity('ses_current', { id: 'ses_other' }, global)).toBe(global)
  })

  test('returns null for an empty ID or when every candidate mismatches', () => {
    expect(resolveCurrentSessionEntity('', { id: 'ses_current' }, null)).toBeNull()
    expect(resolveCurrentSessionEntity('ses_current', { id: 'ses_other' }, null)).toBeNull()
    expect(resolveCurrentSessionEntity('ses_current', { id: 'ses_other' }, { id: 'ses_another' })).toBeNull()
  })
})

describe('resolveParentSessionTarget', () => {
  test('uses the cached parent entity and its directory', () => {
    const current: Session = { id: 'ses_child', parentID: 'ses_parent', directory: '/child-directory' }
    const parent: Session = { id: 'ses_parent', directory: '/parent-directory' }

    expect(resolveParentSessionTarget('ses_child', current, parent, '/fallback')).toEqual({
      id: 'ses_parent',
      directory: '/parent-directory',
      session: parent,
    })
  })

  test('keeps a parent navigation target when its entity is missing', () => {
    const current: Session = { id: 'ses_child', parentID: 'ses_parent', directory: '/child-directory' }

    expect(resolveParentSessionTarget('ses_child', current, null, '/fallback')).toEqual({
      id: 'ses_parent',
      directory: '/child-directory',
      session: null,
    })
  })

  test('uses the fallback directory when neither entity provides one', () => {
    const current: Session = { id: 'ses_child', parentID: 'ses_parent' }

    expect(resolveParentSessionTarget('ses_child', current, null, '/fallback')).toEqual({
      id: 'ses_parent',
      directory: '/fallback',
      session: null,
    })
  })

  test('returns null for a mismatched current entity and a root session', () => {
    expect(resolveParentSessionTarget('ses_child', { id: 'ses_other', parentID: 'ses_parent' }, null, '/fallback')).toBeNull()
    expect(resolveParentSessionTarget('ses_root', { id: 'ses_root' }, null, '/fallback')).toBeNull()
  })
})
