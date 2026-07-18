export const resolveDirectoryExplorerMobileLayout = (
  forceMobile: boolean | undefined,
  isMobile: boolean,
): boolean => forceMobile ?? isMobile;
