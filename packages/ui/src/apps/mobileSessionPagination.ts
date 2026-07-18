export const getMobileSessionPageSize = (hasWorktrees: boolean): number =>
  hasWorktrees ? 5 : 20;
