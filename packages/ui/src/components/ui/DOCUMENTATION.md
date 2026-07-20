# Mobile Window Motion

`MobileWindowMotion` owns mobile overlay motion. React owns discrete presence and modal state. Interaction frames write only the component-owned scrim and surface `transform` and `opacity` styles.

`begin(operation)` accepts `present` and `dismiss` and returns whether the interaction started. `update(progress)` receives the current operation completion from `0` through `1`: present maps directly to visible progress, dismiss maps to `1 - progress`. `finish(commit | cancel)` resolves through the recipe: present commits visible and cancels hidden; dismiss commits hidden and cancels visible.

Modes are `standard`, `interactive-present`, and `interactive-dismiss`. Each interaction has a generation; stale updates and settlements cannot affect a newer interaction. Settlement reads the latest controlled `open` value after requesting its commit, then converges to the controlled endpoint before unmounting.

`MobileWindowStack` owns shared modal ordering and body locking for Motion instances. Its first modal saves and locks body overflow; its final modal restores it. Escape, focus trapping, and `aria-modal` apply to the stack top. Lower stack entries receive `aria-hidden` and `inert`. Present previews mount with `aria-hidden` and `inert` and remain outside the stack.

Frame updates use one rAF to coalesce input. Interaction frames avoid root CSS variables, global DOM queries, layout reads, and per-frame React state. Sheet layouts derive from their edge. WAAPI owns settling, interruption reads the active computed progress, and reduced-motion completes synchronously. Capacitor Motion surfaces disable keyboard-bottom transitions while interaction or settlement owns compositor opacity.

`MobileWindowMotionRegistry` provides a narrow imperative bridge and unregisters controllers when the component unmounts or its id changes. Controller lifetime remains independent from surface presence. The mobile Sessions sheet is the current first caller and starts its header-swipe preview with `begin('present')`. Future callers may use the registry for local gesture ownership while keeping presence, modal state, and visual-frame ownership inside `MobileWindowMotion`.

The Sessions sheet exposes a dedicated top resize handle with `72dvh` and `98dvh` snap points. Drag frames write height directly to the motion surface through `surfaceElementRef`, one write per animation frame; release settles with a height animation and React commits the selected snap class. The handle is reserved from the sheet-wide dismiss recognizer, while list-edge downward gestures continue to own dismissal. Current-turn and direct single-file mobile diffs open at `98dvh` and use the same resize behavior. Both presentations include backdrop dismissal and an explicit close action.

`MobileWindowMotion` owns dismissal configuration through `dismissGesture`: its default is disabled, `true` uses defaults, and an object enables the gesture with option overrides. Motion attaches the hook to its real surface, which supplies the edge and surface travel size. The hook supports `top`, `bottom`, `left`, and `right`; it locks scroll ownership at `touchstart` by choosing the nearest target-axis scrollable ancestor. A matching selector provides a checked fallback within the surface. A target scroll container keeps the full gesture when the touch starts away from its matching edge, and a later touch starting at that edge becomes eligible for dismissal. Commit distance uses its own ratio and min/max bounds, separate from the surface-sized animation travel; a correctly directed fling can also commit.

`MobileSheetSnap` owns the shared `72dvh` / `98dvh` resize gesture and accessible drag handle used by Sessions and mobile diffs. The handle can move upward to `98dvh` and continuously downward to zero; releasing below the dismissal threshold closes the owning sheet, while shorter gestures settle to the nearest snap.

`MobileResizableSheet` is the product-level assembly for standard resizable mobile sheets. It combines `MobileWindowMotion`, `MobileSheetSnapHandle`, the shared snap lifecycle, title, and close action. Current-turn and direct single-file diff viewers use this entrypoint; Sessions uses the same lower-level pieces with its custom header and interactive-present bridge.

`keepMounted` preserves a surface's Portal subtree after its first presentation. A preserved hidden surface leaves the modal stack, releases body and focus ownership, becomes inert and invisible, and retains child state and native scroll position for its next presentation. The mobile Sessions window enables this behavior while continuing to refresh authoritative session snapshots when opened.

`MobileOverlayPanel` keeps its scrollable body as the default. Its opt-in `containedBody` mode provides a fixed, overflow-contained body for children that own their internal scroll region, including the scheduled-tasks workspace and its editor page.

`mobileLongPress.ts` owns the shared 500ms touch/pen hold controller for mobile action surfaces. It cancels on movement beyond 12px, release, or pointer cancellation and consumes the click generated by a completed hold. Both dedicated mobile sessions and the responsive Web sessions sheet use this controller.

## Grouped Cards

`grouped-card.styles.ts` exports opt-in grouped-card recipes for compact settings and editor surfaces. `groupedCardClassName` owns the single elevated surface and outer border, `groupedCardRowClassName` owns consistent row height and inset separators, and `groupedSectionTitleClassName` owns the section label. Controls inside a grouped row keep their own interaction affordance while the row remains part of one shared card layer.
