/**
 * Client-generated message/part ID matching OpenCode's Identifier.ascending format.
 * Uses BigInt(timestamp) * 0x1000 + counter, encoded as 6 hex bytes + random base62.
 * This ensures client-generated IDs sort correctly with server-generated ones.
 */

let lastAscendingValue = 0n

const BASE62 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
const RANDOM_LENGTH = 14

function randomBase62(length: number): string {
  let result = ""
  for (let i = 0; i < length; i++) {
    result += BASE62[Math.floor(Math.random() * 62)]
  }
  return result
}

const HEX_SORT_SEGMENT = /^[0-9a-f]{12}$/
const BASE62_SEGMENT = /^[0-9A-Za-z]{14}$/
const VALUE_MASK = (1n << 48n) - 1n

const floorValue = (prefix: string, floorID?: string): bigint | undefined => {
  if (typeof floorID !== "string" || !floorID.startsWith(`${prefix}_`)) return undefined
  const suffix = floorID.slice(prefix.length + 1)
  const hex = suffix.slice(0, 12)
  if (!HEX_SORT_SEGMENT.test(hex) || !BASE62_SEGMENT.test(suffix.slice(12))) return undefined
  return BigInt(`0x${hex}`)
}

export const ascendingIdAfter = (prefix: string, floorID?: string): string => {
  const base = (BigInt(Date.now()) * 0x1000n) & VALUE_MASK
  const floor = floorValue(prefix, floorID) ?? 0n
  const maximum = [base, lastAscendingValue, floor].reduce((current, candidate) => current > candidate ? current : candidate)
  if (maximum >= VALUE_MASK) throw new Error("Ascending ID space exhausted")
  const value = maximum + 1n
  lastAscendingValue = value
  const bytes = new Uint8Array(6)
  for (let i = 0; i < 6; i++) {
    bytes[i] = Number((value >> BigInt(40 - 8 * i)) & BigInt(0xff))
  }

  let hex = ""
  for (let i = 0; i < bytes.length; i++) {
    hex += bytes[i].toString(16).padStart(2, "0")
  }

  return `${prefix}_${hex}${randomBase62(RANDOM_LENGTH)}`
}

export const ascendingId = (prefix: string): string => ascendingIdAfter(prefix)
