export const shouldSubmitCommandOnSelection = (
  command: { isSkill?: boolean },
  submitIntent: boolean,
): boolean => submitIntent && !command.isSkill;
