/**
 * Client-generated message/part ID matching OpenCode's Identifier.ascending format.
 * Uses BigInt(timestamp) * 0x1000 + counter, encoded as 6 hex bytes + random base62.
 * This ensures client-generated IDs sort correctly with server-generated ones.
 */

let lastIdTimestamp = 0
let idCounter = 0

const BASE62 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
const RANDOM_LENGTH = 14

function randomBase62(length: number): string {
  let result = ""
  for (let i = 0; i < length; i++) {
    result += BASE62[Math.floor(Math.random() * 62)]
  }
  return result
}

export const ascendingId = (prefix: string): string => {
  const now = Date.now()
  if (now !== lastIdTimestamp) {
    lastIdTimestamp = now
    idCounter = 0
  }
  idCounter += 1

  const value = BigInt(now) * BigInt(0x1000) + BigInt(idCounter)
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
