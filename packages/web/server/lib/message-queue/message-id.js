import { randomBytes } from 'node:crypto';

const BASE62 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
const RANDOM_LENGTH = 14;
const VALUE_MASK = (1n << 48n) - 1n;
const HEX_SORT_SEGMENT = /^[0-9a-f]{12}$/;
const BASE62_SEGMENT = /^[0-9A-Za-z]{14}$/;

let last = 0n;

const randomBase62 = (length) => {
  let result = '';
  while (result.length < length) {
    for (const byte of randomBytes(length)) {
      if (byte < 248) result += BASE62[byte % 62];
      if (result.length === length) return result;
    }
  }
  return result;
};

const floorValue = (floor) => {
  if (typeof floor !== 'string' || !floor.startsWith('msg_')) return 0n;
  const suffix = floor.slice(4);
  const hex = suffix.slice(0, 12);
  if (!HEX_SORT_SEGMENT.test(hex) || !BASE62_SEGMENT.test(suffix.slice(12))) return 0n;
  return BigInt(`0x${hex}`);
};

const clockValue = (clock) => {
  const value = clock();
  if (typeof value === 'bigint') return value;
  return Number.isFinite(value) ? BigInt(Math.trunc(value)) : 0n;
};

export const createAscendingMessageID = (floor, clock = () => Date.now()) => {
  const base = (clockValue(clock) * 0x1000n) & VALUE_MASK;
  const maximum = [base, last, floorValue(floor)].reduce((current, candidate) => current > candidate ? current : candidate);
  if (maximum >= VALUE_MASK) throw new Error('Ascending ID space exhausted');
  const value = maximum + 1n;
  last = value;
  return `msg_${value.toString(16).padStart(12, '0')}${randomBase62(RANDOM_LENGTH)}`;
};
