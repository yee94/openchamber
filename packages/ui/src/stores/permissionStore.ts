import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { Session } from "@opencode-ai/sdk/v2/client";
import { autoRespondsPermission, type PermissionAutoAcceptMap } from "./utils/permissionAutoAccept";
import { getAllSyncSessionMap } from "@/sync/sync-refs";
import { runtimeFetch } from "@/lib/runtime-fetch";
import { isVSCodeRuntime } from "@/lib/desktop";
import { createDeferredSafeJSONStorage } from "./utils/safeStorage";
import { useSessionUIStore } from "@/sync/session-ui-store";
import { opencodeClient } from "@/lib/opencode/client";
import { getRuntimeKey } from "@/lib/runtime-switch";

type PermissionPolicySnapshot = {
    sessions: PermissionAutoAcceptMap;
};

interface PermissionStore {
    autoAccept: PermissionAutoAcceptMap;
    controlVisibility: Record<string, boolean>;
    loaded: boolean;
    saving: boolean;
    hydrate: () => Promise<void>;
    applySnapshot: (snapshot: PermissionPolicySnapshot) => void;
    reset: () => void;
    isSessionAutoAccepting: (sessionId: string) => boolean;
    revalidateControlVisibility: (directory?: string, agentName?: string) => Promise<void>;
    setSessionAutoAccept: (sessionId: string, enabled: boolean) => Promise<void>;
}

const controlVisibilityRequests = new Map<string, Promise<void>>();

export const getPermissionControlVisibilityKey = (directory?: string, agentName?: string): string =>
    `${getRuntimeKey()}\n${directory?.trim() ?? ""}\n${agentName?.trim() ?? ""}`;

const readSnapshot = async (response: Response): Promise<PermissionPolicySnapshot> => {
    if (!response.ok) throw new Error(`Permission auto-accept request failed (${response.status})`);
    const payload = await response.json() as Partial<PermissionPolicySnapshot>;
    if (!payload.sessions || typeof payload.sessions !== "object") {
        throw new Error("Invalid permission auto-accept response");
    }
    const sessions: PermissionAutoAcceptMap = {};
    for (const [sessionId, enabled] of Object.entries(payload.sessions)) {
        if (sessionId && typeof enabled === "boolean") sessions[sessionId] = enabled;
    }
    return { sessions };
};

const requestSnapshot = async (path: string, init?: RequestInit) => readSnapshot(await runtimeFetch(path, init));

const isAutoAccepting = (
    autoAccept: PermissionAutoAcceptMap,
    sessionById: ReadonlyMap<string, Session>,
    sessionId: string,
) => autoRespondsPermission({ autoAccept, sessions: [], sessionById, sessionID: sessionId });

export const usePermissionStore = create<PermissionStore>()(persist((set, get) => ({
    autoAccept: {},
    controlVisibility: {},
    loaded: false,
    saving: false,

    hydrate: async () => {
        let snapshot = await requestSnapshot("/api/permission-auto-accept");
        const legacyEntries = Object.entries(get().autoAccept)
            .filter(([sessionId, enabled]) => !sessionId.includes("/") && typeof enabled === "boolean");
        if (Object.keys(snapshot.sessions).length === 0 && legacyEntries.length > 0) {
            for (const [sessionId, enabled] of legacyEntries) {
                if (!sessionId || typeof enabled !== "boolean") continue;
                snapshot = await requestSnapshot(
                    `/api/permission-auto-accept/sessions/${encodeURIComponent(sessionId)}`,
                    {
                        method: "PUT",
                        headers: { "Content-Type": "application/json" },
                        body: JSON.stringify({ enabled }),
                    },
                );
            }
        }
        set({ autoAccept: snapshot.sessions, loaded: true });
    },

    reset: () => {
        controlVisibilityRequests.clear();
        set({ autoAccept: {}, controlVisibility: {}, loaded: false, saving: false });
    },

    applySnapshot: (snapshot) => {
        const sessions: PermissionAutoAcceptMap = {};
        for (const [sessionId, enabled] of Object.entries(snapshot.sessions ?? {})) {
            if (sessionId && typeof enabled === "boolean") sessions[sessionId] = enabled;
        }
        set({ autoAccept: sessions, loaded: true });
    },

    isSessionAutoAccepting: (sessionId) => {
        if (!sessionId) return false;
        const autoAccept = get().autoAccept;
        if (Object.keys(autoAccept).length === 0) return false;
        return isAutoAccepting(autoAccept, getAllSyncSessionMap(), sessionId);
    },

    revalidateControlVisibility: async (directory, agentName) => {
        if (isVSCodeRuntime()) return;
        const key = getPermissionControlVisibilityKey(directory, agentName);
        const existing = controlVisibilityRequests.get(key);
        if (existing) return existing;
        const query = new URLSearchParams();
        if (directory?.trim()) query.set("directory", directory.trim());
        if (agentName?.trim()) query.set("agent", agentName.trim());
        const queryString = query.size > 0 ? `?${query.toString()}` : "";
        const request = (async () => {
            const response = await runtimeFetch(`/api/permission-auto-accept/control-visibility${queryString}`);
            if (!response.ok) throw new Error(`Permission control visibility request failed (${response.status})`);
            const payload = await response.json() as { visible?: unknown };
            if (typeof payload.visible !== "boolean") {
                throw new Error("Invalid permission control visibility response");
            }
            const visible = payload.visible;
            set((state) => ({
                controlVisibility: { ...state.controlVisibility, [key]: visible },
            }));
        })().finally(() => {
            controlVisibilityRequests.delete(key);
        });
        controlVisibilityRequests.set(key, request);
        return request;
    },

    setSessionAutoAccept: async (sessionId, enabled) => {
        if (!sessionId) return;
        if (isVSCodeRuntime()) {
            const response = await runtimeFetch("/api/notifications/auto-accept", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ sessionId, enabled }),
            });
            if (!response.ok) throw new Error(`Permission auto-accept request failed (${response.status})`);
            set((state) => ({ autoAccept: { ...state.autoAccept, [sessionId]: enabled }, loaded: true }));
            return;
        }
        set({ saving: true });
        try {
            const directory = useSessionUIStore.getState().getDirectoryForSession(sessionId)
                ?? opencodeClient.getDirectory()
                ?? undefined;
            const snapshot = await requestSnapshot(
                `/api/permission-auto-accept/sessions/${encodeURIComponent(sessionId)}`,
                {
                    method: "PUT",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ enabled, directory }),
                },
            );
            set({ autoAccept: snapshot.sessions, loaded: true });
        } finally {
            set({ saving: false });
        }
    },

}), {
    name: "permission-store",
    storage: createDeferredSafeJSONStorage(),
    partialize: (state) => ({
        autoAccept: state.autoAccept,
        controlVisibility: state.controlVisibility,
    }),
}));
