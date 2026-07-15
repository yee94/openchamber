type ImmediateSessionCommandAction = {
    command: 'compact' | 'fork';
    consumeCommandText: () => void;
    forkSession: () => Promise<unknown>;
    waitForConnection: () => Promise<void>;
    getDirectoryForSession: () => string | null;
    summarizeSession: (directory: string) => Promise<unknown>;
    onCompactError: () => void;
    onForkError: (error: unknown) => void;
};

/** Runs an immediate session command after synchronously consuming only its text. */
export const runImmediateSessionCommand = async ({
    command,
    consumeCommandText,
    forkSession,
    waitForConnection,
    getDirectoryForSession,
    summarizeSession,
    onCompactError,
    onForkError,
}: ImmediateSessionCommandAction): Promise<void> => {
    consumeCommandText();

    if (command === 'fork') {
        try {
            await forkSession();
        } catch (error) {
            onForkError(error);
        }
        return;
    }

    try {
        await waitForConnection();
        const directory = getDirectoryForSession();
        if (!directory) {
            onCompactError();
            return;
        }
        await summarizeSession(directory);
    } catch {
        onCompactError();
    }
};
