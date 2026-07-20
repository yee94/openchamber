let last = 0;

export const createAscendingMessageID = (floor, clock = () => Date.now()) => {
  const floorValue = typeof floor === 'string' && /^msg_[0-9a-z]+$/.test(floor) ? Number.parseInt(floor.slice(4), 36) : 0;
  last = Math.max(last + 1, floorValue + 1, Math.trunc(clock()));
  return `msg_${last.toString(36).padStart(10, '0')}`;
};
