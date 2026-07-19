import React from "react";
import { Button } from "@/components/ui/button";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Icon } from "@/components/icon/Icon";
import { useI18n } from "@/lib/i18n";

type Props = {
  onOpenSettings: () => void;
  onOpenShortcuts: () => void;
  onOpenUpdate?: () => void;
  showRuntimeButtons?: boolean;
  showUpdateButton?: boolean;
};

const footerIconButtonClassName =
  "size-8 text-muted-foreground hover:bg-[var(--interactive-hover)]/50 hover:text-foreground";

export function SidebarFooter({
  onOpenSettings,
  onOpenShortcuts,
  onOpenUpdate,
  showRuntimeButtons = true,
  showUpdateButton = false,
}: Props): React.ReactNode {
  const { t } = useI18n();

  return (
    <div className="flex shrink-0 items-center justify-start gap-1 px-2.5 py-2">
      {showRuntimeButtons ? (
        <>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className={footerIconButtonClassName}
                onClick={onOpenSettings}
                aria-label={t("sessions.sidebar.footer.actions.settings")}
              >
                <Icon name="settings-3" className="size-4.5" />
              </Button>
            </TooltipTrigger>
            <TooltipContent side="top" sideOffset={4}>
              {t("sessions.sidebar.footer.actions.settings")}
            </TooltipContent>
          </Tooltip>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className={footerIconButtonClassName}
                onClick={onOpenShortcuts}
                aria-label={t("sessions.sidebar.footer.actions.shortcuts")}
              >
                <Icon name="question" className="size-4.5" />
              </Button>
            </TooltipTrigger>
            <TooltipContent side="top" sideOffset={4}>
              {t("sessions.sidebar.footer.actions.shortcuts")}
            </TooltipContent>
          </Tooltip>
        </>
      ) : null}
      {showUpdateButton && onOpenUpdate ? (
        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              type="button"
              variant="default"
              size="icon"
              className="ml-auto size-7 rounded-full border-[var(--primary-base)] bg-[var(--primary-base)] text-[var(--primary-foreground)] hover:bg-[var(--primary-hover)] hover:text-[var(--primary-foreground)] active:bg-[var(--primary-hover)] dark:border-[var(--primary-base)] dark:bg-[var(--primary-base)] dark:text-[var(--primary-foreground)] dark:hover:bg-[var(--primary-hover)] dark:hover:text-[var(--primary-foreground)] dark:active:bg-[var(--primary-hover)]"
              onClick={onOpenUpdate}
              aria-label={t("sessions.sidebar.footer.actions.update")}
            >
              <Icon name="download" className="size-3.5" />
            </Button>
          </TooltipTrigger>
          <TooltipContent side="top" sideOffset={4}>
            <p>{t("sessions.sidebar.footer.actions.update")}</p>
          </TooltipContent>
        </Tooltip>
      ) : null}
    </div>
  );
}
