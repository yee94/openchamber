export const shouldLoadAvailableProviders = (isAddMode: boolean): boolean => isAddMode;

export const filterMethodsWithIndex = <T>(methods: T[], matches: (method: T) => boolean) =>
  methods.flatMap((method, methodIndex) => (matches(method) ? [{ method, methodIndex }] : []));
