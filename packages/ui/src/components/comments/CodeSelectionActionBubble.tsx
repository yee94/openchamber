import React from 'react';
import { createPortal } from 'react-dom';

import { Icon } from '@/components/icon/Icon';
import { Button } from '@/components/ui/button';
import { ShortcutKbd } from '@/components/ui/kbd';
import { useI18n } from '@/lib/i18n';

type CodeSelectionActionBubbleProps = {
  position: { x: number; y: number };
  onAddToChat: () => void;
};

export function CodeSelectionActionBubble({ position, onAddToChat }: CodeSelectionActionBubbleProps) {
  const { t } = useI18n();

  return createPortal(
    <div
      data-code-selection-action="true"
      className="fixed z-[100] -translate-y-full rounded-lg border border-[var(--interactive-border)] bg-[var(--surface-elevated)] p-1 shadow-lg"
      style={{ left: position.x, top: position.y }}
      onPointerDown={(event) => event.preventDefault()}
    >
      <Button variant="ghost" size="sm" className="h-7 gap-1.5 px-2" onClick={onAddToChat}>
        <Icon name="add" className="size-4" />
        {t('chat.textSelection.actions.addToChat')}
        <ShortcutKbd shortcut="⌘+I" />
      </Button>
    </div>,
    document.body,
  );
}
