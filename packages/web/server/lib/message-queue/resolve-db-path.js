import path from 'node:path';

export const resolveMessageQueueDbPath = ({ messageQueueDbPath } = {}, openchamberDataDir) => {
  if (messageQueueDbPath === null) return null;
  if (typeof messageQueueDbPath === 'string' && messageQueueDbPath.trim()) return messageQueueDbPath;
  if (typeof openchamberDataDir !== 'string' || !openchamberDataDir.trim()) return null;
  return path.join(openchamberDataDir, 'message-queue.sqlite');
};
