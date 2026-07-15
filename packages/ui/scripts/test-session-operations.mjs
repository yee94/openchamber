import { fileURLToPath } from 'node:url';

const packageRoot = fileURLToPath(new URL('..', import.meta.url));
const testFiles = [
    'src/stores/messageQueueStore.test.ts',
    'src/stores/message-queue-ledger.test.ts',
    'src/stores/message-queue-migration.test.ts',
    'src/sync/input-draft-types.test.ts',
    'src/sync/input-draft-blob-store.test.ts',
    'src/sync/input-draft-metadata-store.test.ts',
    'src/sync/input-draft-durability-coordinator.test.ts',
    'src/sync/input-draft-state.test.ts',
    'src/sync/input-draft-attachments.test.ts',
    'src/sync/input-draft-attachment-failures.test.ts',
    'src/sync/input-draft-attachment-concurrency.test.ts',
    'src/sync/queue-attachment-coordinator.test.ts',
    'src/sync/message-queue-runtime-controller.test.ts',
    'src/sync/message-queue-runtime.test.ts',
    'src/sync/message-queue-dispatch.test.ts',
    'src/sync/input-store.test.ts',
    'src/lib/runtime-switch.test.ts',
    'src/sync/child-store.test.ts',
    'src/sync/scoped-session-status.test.ts',
    'src/sync/session-actions.test.ts',
    'src/sync/session-combined-send.test.ts',
    'src/hooks/useQueuedMessageAutoSend.test.ts',
    'src/components/chat/localCommandClassifier.test.ts',
    'src/components/chat/queueAdmission.test.ts',
    'src/components/chat/QueuedMessageChips.test.ts',
];

for (const testFile of testFiles) {
    const child = Bun.spawn([process.execPath, 'test', testFile], {
        cwd: packageRoot,
        stdout: 'inherit',
        stderr: 'inherit',
    });
    if (await child.exited !== 0) {
        process.exitCode = 1;
        break;
    }
}
