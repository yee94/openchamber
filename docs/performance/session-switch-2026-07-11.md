# Session switch performance report

Date: 2026-07-11

## Outcome

The session row highlight is now committed independently from the authoritative
session switch and the heavy chat tree. In the six-switch development-mode
verification run, highlight latency was 18.7–27.8 ms. The new chat tree committed
in 89.5–312.1 ms while Markdown blocks and historical tools continued hydrating
in bounded background slices.

The absolute numbers below come from React/Vite development mode. Development
mode includes StrictMode and React DEV instrumentation, so production should be
faster; the acceptance gates intentionally use the slower development build.

## Baseline trace

Source: `Trace-20260711T002320.json.gz` supplied by the reporter.

Reproducible command:

```sh
python3 scripts/perf/analyze-session-switch-trace.py \
  /path/to/Trace-20260711T002320.json.gz
```

| Metric | Baseline |
| --- | ---: |
| Click samples | 6 |
| Click processing median | 258.94 ms |
| Click processing p95 / max | 1272.64 ms |
| Main-thread long tasks | 12 |
| Worst long task | 2291.68 ms |
| ParseHTML inside click windows | 42.25 ms |
| UpdateLayoutTree inside click windows | 62.55 ms |
| Layout inside click windows | 30.86 ms |
| Minor GC inside click windows | 56.31 ms |

The worst click spent about 1.27 seconds in its handler. The surrounding React
work included roughly 229 ms render, 373 ms commit, 324 ms effects, then another
249 ms render. A separate 2.29-second task contained about 568 ms render, 660 ms
commit, and 1037 ms effects.

The trace showed four causal groups:

1. The session ID was updated synchronously, so the sidebar highlight shared a
   batch with the entire chat remount.
2. The latest completed turn was always treated as a streaming tail and escaped
   history virtualization.
3. Historical Markdown synchronously ran parse, DOMPurify, decoration, and DOM
   insertion before paint; historical tools also registered layout effects even
   when animation was disabled.
4. Closed dialogs and broad sidebar/DnD consumers remained mounted and joined
   unrelated selection commits.

## Changes

### Selection and scheduling

- Added a narrow sidebar visual-selection store. Each row subscribes only to
  `state.sessionId === row.id`, so a click re-renders the old and new rows rather
  than the complete project tree.
- The visual row update commits first. The selected row's layout effect then
  schedules the authoritative session switch after a paint opportunity.
- Rapid switches cancel the intermediate authoritative commit.
- The chat root shows an inert lightweight surface during the authority change,
  preventing stale-session input or actions.
- Added User Timing measures:
  - `openchamber.session-switch.highlight-latency`
  - `openchamber.session-switch.content-latency`

### Historical rendering

- Only a genuinely working/streaming latest turn is kept outside virtualized
  history. Completed latest turns use the same virtualizer as older turns.
- Initial history overscan starts at 2 and grows by 2 in the shared frame-budget
  queue instead of mounting 8 desktop / 16 mobile overscan turns at once.
- Completed Markdown first paints a safe text fallback, then parses and commits
  rich Markdown block by block. Work is cancelled when the row/session unmounts.
- Historical tool bodies hydrate individually through the same queue. Hydrated
  tool IDs are retained in a count-and-byte bounded LRU so scrolling does not
  repeatedly show placeholders.
- `animate=false` reveal paths no longer register layout/effect hooks.

### Waste and cache control

- Tool output dialogs, plan dialogs, update/project dialogs, and the large new
  worktree dialog mount only while open.
- Synchronous Markdown HTML is cached, and Markdown, Mermaid, tool hydration,
  and turn projection caches are bounded by both entry count and estimated bytes.
- Turn projection cache keys are computed once per projection attempt instead of
  twice on a miss.

## Optimized verification

Environment: the same local data, React StrictMode, Vite development server,
three historical Agent Tracker sessions, six consecutive switches with 500 ms
between selections.

| Sample | Highlight painted | Chat content committed |
| ---: | ---: | ---: |
| 1 | 18.7 ms | 91.9 ms |
| 2 | 25.3 ms | 89.5 ms |
| 3 | 22.1 ms | 129.0 ms |
| 4 | 26.8 ms | 312.1 ms |
| 5 | 27.8 ms | 167.7 ms |
| 6 | 27.7 ms | 156.8 ms |
| Median | **26.05 ms** | **142.90 ms** |
| p95 / max | **27.8 ms** | **312.1 ms** |

Compared with the original trace's click-processing figures:

- Median highlight latency is 89.9% lower than the baseline median click task.
- Worst highlight latency is 97.8% lower than the baseline worst click task.
- Median content commit is 44.8% lower; the worst sampled content commit is
  75.5% lower.

The baseline click slice and the new User Timing measures are not identical
browser metrics, so these percentages describe user-visible critical-path
improvement rather than a laboratory A/B of the same trace event. A follow-up
Chrome recording can be passed to the analyzer to compare click slices and long
tasks on exactly the same basis; the User Timing measures will also appear in
that trace.

## Acceptance gates

| Gate (development mode) | Result |
| --- | --- |
| Highlight p95 < 50 ms | Pass: 27.8 ms |
| Content commit median < 200 ms | Pass: 142.9 ms |
| Content commit p95 < 350 ms | Pass: 312.1 ms |
| Rapid switch keeps only latest authority commit | Pass: unit test |
| Historical rich work is cancellable and frame-budgeted | Pass: unit tests + interactive run |
| UI type-check | Pass |
| Edited-file lint | Pass |

## Regression commands

```sh
bun test \
  packages/ui/src/lib/afterPaintTaskQueue.test.ts \
  packages/ui/src/lib/dualLimitLru.test.ts \
  packages/ui/src/components/chat/hooks/useTurnRecords.test.ts \
  packages/ui/src/components/chat/lib/historyOverscan.test.ts \
  packages/ui/src/components/chat/lib/turns/turnProjectionCache.test.ts \
  packages/ui/src/components/session/sidebar/sidebarVisualSelection.test.ts \
  packages/ui/src/components/session/sidebar/hooks/useProjectSessionSelection.test.ts

bun run --cwd packages/ui type-check
bun run --cwd packages/ui lint
```
