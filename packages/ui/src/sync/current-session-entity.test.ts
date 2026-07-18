import { describe, expect, test } from 'bun:test'

import { resolveCurrentSessionEntity } from './current-session-entity'

type Session = {
  id: string
  title?: string | null
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
