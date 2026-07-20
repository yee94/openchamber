export const isMessageQueueRoute = (pathname: string): boolean => (
  pathname.replace(/\/+$/, '') === '/api/openchamber/message-queue'
  || pathname.startsWith('/api/openchamber/message-queue/')
);
