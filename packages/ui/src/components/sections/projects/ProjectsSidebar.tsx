import React from 'react';
import { useProjectsStore } from '@/stores/useProjectsStore';
import { useUIStore } from '@/stores/useUIStore';
import { Button } from '@/components/ui/button';
import { SettingsSidebarLayout } from '@/components/sections/shared/SettingsSidebarLayout';
import { SettingsSidebarItem } from '@/components/sections/shared/SettingsSidebarItem';
import { Icon } from "@/components/icon/Icon";
import { cn } from '@/lib/utils';
import { isVSCodeRuntime } from '@/lib/desktop';
import { sessionEvents } from '@/lib/sessionEvents';
import { useI18n } from '@/lib/i18n';

export const ProjectsSidebar: React.FC<{ onItemSelect?: () => void }> = ({ onItemSelect }) => {
  const { t } = useI18n();
  const projects = useProjectsStore((state) => state.projects);
  const selectedId = useUIStore((state) => state.settingsProjectsSelectedId);
  const setSelectedId = useUIStore((state) => state.setSettingsProjectsSelectedId);

  const isVSCode = React.useMemo(() => isVSCodeRuntime(), []);

  const handleAddProject = React.useCallback(() => {
    sessionEvents.requestDirectoryDialog();
  }, []);

  React.useEffect(() => {
    if (projects.length === 0) {
      if (selectedId !== null) {
        setSelectedId(null);
      }
      return;
    }
    if (selectedId && projects.some((p) => p.id === selectedId)) {
      return;
    }
    setSelectedId(projects[0].id);
  }, [projects, selectedId, setSelectedId]);

  return (
    <SettingsSidebarLayout
      variant="background"
      header={
        <div className={cn('border-b px-3', 'pt-4 pb-3')}>
          <h2 className="text-base font-semibold text-foreground mb-3">{t('settings.page.projects.title')}</h2>
          <div className="flex items-center justify-between gap-2">
            <span className="typography-meta text-muted-foreground">{t('settings.projects.sidebar.total', { count: projects.length })}</span>
            {!isVSCode && (
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className="h-7 w-7 -my-1 text-muted-foreground"
                onClick={handleAddProject}
                aria-label={t('settings.projects.sidebar.actions.addProject')}
              >
                <Icon name="add" className="size-4" />
              </Button>
            )}
          </div>
        </div>
      }
    >
      {projects.map((project) => {
        const selected = project.id === selectedId;
        // Codex-style: muted open-folder only — no per-project color/icon chrome.
        const icon = (
          <Icon name="folder" className={cn('h-4 w-4', selected ? 'text-foreground' : 'text-muted-foreground')} />
        );

        return (
          <SettingsSidebarItem
            key={project.id}
            title={project.label || project.path}
            icon={icon}
            selected={selected}
            onSelect={() => {
              setSelectedId(project.id);
              onItemSelect?.();
            }}
          />
        );
      })}
    </SettingsSidebarLayout>
  );
};
