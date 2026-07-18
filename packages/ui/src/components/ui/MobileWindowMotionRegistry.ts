import type {
  MobileWindowMotionFinish,
  MobileWindowMotionOperation,
} from './MobileWindowMotionRecipe';

export const MOBILE_SESSIONS_WINDOW_ID = 'mobile-sessions';

export type MobileWindowMotionController = {
  begin: (operation: MobileWindowMotionOperation) => boolean;
  update: (progress: number) => void;
  finish: (finish: MobileWindowMotionFinish) => void;
  interrupt: () => void;
};

const controllers = new Map<string, MobileWindowMotionController>();

export const getMobileWindowMotionController = (id: string): MobileWindowMotionController | null => (
  controllers.get(id) ?? null
);

export const registerMobileWindowMotionController = (
  id: string,
  controller: MobileWindowMotionController,
): (() => void) => {
  controllers.set(id, controller);
  return () => {
    if (controllers.get(id) === controller) controllers.delete(id);
  };
};
