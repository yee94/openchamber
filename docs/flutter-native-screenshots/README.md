# Flutter native screenshots (Yee visual review)

Real `apps/mobile_flutter` widgets, captured with `WidgetTester` + `RenderRepaintBoundary.toImage`.

- Device: **390×844** logical pixels, `devicePixelRatio` **3** (PNG 1170×2532)
- Locale: **zh-CN**
- Regenerator: `apps/mobile_flutter/test/flutter_native_screenshots_test.dart`
- Fonts: `test/review_fonts.dart` loads Roboto Regular+Medium. CJK Regular stays WenQuanYi Micro Hei; **Noto Sans CJK SC Medium** loads when `fonts-noto-cjk-extra` is present (SC face from the TTC) so official `font-medium` / `font-semibold` titles are a real Medium cut — not a miter stem, not Regular clamped to w400, not Noto Bold. Droid is last fallback. **Chrome icons are painted `OcGlyph` paths** — do not accept empty-square CupertinoIcons tofu.
- WidgetTester runs as Android. Header / dock use clipped `BackdropFilter` through-plates (iOS 26 live chrome is UIKit `UIGlassEffect`; these PNGs cannot prove that). Search uses `OcGlassChip` through-frost (`glassChipThrough` 0.22, σ14, official saturate, 36 plate — not a 0.34 cream coin, no 8/20 umbra, no 0.68 coin). Chat / schedule discs keep `glassChipFill` 0.34. Solid `+` is official 40 primary. Chat detail-nav chips are the official 40 `mobileIcon` hit. Project shells keep the official float-shadow trio — near pair (2 + 12) plus far 10/24/-6 as true black at official 10% (`rgb(0 0 0 / 0.1)`; official `0 10px 24px -6px`, not a WidgetTester -2 loudness knob, not a darker Material umbra). Schedule cards use the same official 10% far with a quieter near pair. Nested worktree groups keep the official 1px inset border, painted a hair darker so the shell reads on cream. No Material 8/20 umbra. Schedule status hit is official 38; painted plate is 28; glyph is 14 at small-chrome stroke 0.62; plate is glassChipThrough + inset highlight (no OcGlassChip frost/chip shadow); schedule ellipsis is 10 at dock 0.12; scheduled-add is official ink (foreground disc). Project / schedule 14/18 titles use cardTitleHalfLead 2.7 (not session 4.7). Dock plate fill is 0 on WidgetTester (cream fill always reads as a stadium). Frost is `blur(20) saturate(1.25)` + glass-shadow near-pair (2/12) so selected `/55` is a through-mix on the list, not a cream pill. Official `floatSurface` 0.45 is too solid here. Chat detail-nav chips stay official 40 `mobileIcon` frost discs (not 44 coins, not flat glyphs). Dock selected is mix-only `interactive-selection/55` (no hairline pill, no RGB@0.55, no nested frost). Session rows stay in the official ~40 class with title 4.7px CJK half-lead plus official title↔subtitle `gap-0.5`; subtitle/time stay the official 10/12 box (40 + 2×4.7 + 0 → 49.4 — not 7.5 half-lead / 70; ceiling ~4.75). Session titles paint `ocCssInk` inside the 16/12 box + pinned 4.7 half-lead as official `font-medium` fill (Noto/PingFang Medium, no miter stem, no shade); Latin stays ReviewSans Medium. Project / page titles use official `font-semibold`. Tracking 1.42 opens the 12px CJK band; project titles use 1.02. Stay under 1.5 / 1.1. Do not pile half-lead. No Medium CJK on review/CI. Project-shell frost (`floatSurface` 0.45) sits behind that ink so 12px cores are not composited through the plate. Project / schedule 14/18 titles paint `ocCssInk` in the official CSS box plus cardTitleHalfLead 2.7 so Regular CJK is not packed; session 4.7 stays on 12px rows only. Card title tracking is 0. Review-face titles (collapsing page title, project/schedule/dock/chat) paint Regular — w600 faux-bold blobs the DroidSansFallback cut. Dock labels paint Regular with 0 tracking so CJK stays open. Project leading / search paint small-chrome stroke 0.62 so 14px glyphs read at dpr 3; dock 23px / settings nav / session-more / schedule-ellipsis stay visual 0.12. Folder / sparkles / calendar / gear all paint 23px at visual stroke 0.12. Composer is official `--surface-subtle` with no elevation / no frost; idle+ready send is official solid foreground `SendCircleIcon` (arrow-up, idle 0.55). File-type marks are stroke-only silhouettes at visual 0.12, not blue squares. Footer action stroke is 0.12. These PNGs cannot prove live iOS glass or 精致. Real iOS still keeps live glass on UIKit overlays. Mid-scroll proof: `02-projects-scrolled.png`. This Linux VM cannot run an iOS Simulator. Goldens reserve `viewPadding.top = 47` for the status area; they do **not** paint a fake UIKit status bar.
- Projects golden expands linked worktree groups after connect so one project shell shows main sessions plus inset worktree groups (official model still starts worktrees collapsed). `.oc-mobile-project-groups` padding (2 / 12 / 14) sits between the project header and the session body.

No PIN / Face ID. No `iosNativeUi`. Chat is a pushed page.

No PIN / Face ID. No `iosNativeUi`. Chat is a pushed page.

Recapture after restoring Yee-open type (tracking + line-height) on top of the small-glyph / soft-shadow chrome. Catalog orange/sand stays — these PNGs are **not** a README photo recolor.

**2026-09-04 wake-1857 residual (after `cd31305e3`):**
Watch scored the live tip (`cd31305e3`, 02=`49b0108a`) and still rejected
chrome: titles too tight/heavy, discs a bit large, far still not official-soft.
`sessionTitleStem` 0.48 → **0.28** (shade stays 0). Project leading **32 → 28**,
schedule status **22 → 18** (glyph 9 → 8); hit 38 stays. Far back to **true
black** at official-soft 4% / tight 2.5% — the 2% *foreground* mix was the
wrong recipe, not that black at 4% was too loud. Trio geometry unchanged.
Do not pile half-lead/tracking. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-1907 residual (after `3dbcae1c3`):**
Watch scored the live tip (`3dbcae1c3`, 02=`2e362d9b`) and still rejected
type: 0.28 stem + session `w500` Regular still read tight/heavy vs
README light air. Stem is the wrong recipe — **0**, fill-only Regular
CJK (`w400`); Latin keeps ReviewSans Medium. Shade stays 0. Discs 28/18
and black far 4%/2.5% stay (official leading is 38; session bullets
already 5). Do not pile half-lead/tracking. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-1914 residual (after `b326d53b1`):**
Watch scored the live tip and still rejected type vs PingFang Medium.
Stem stays **0**. CJK no longer clamps to Regular — session `w500` /
project+page `w600` use a real Medium/Bold cut (review Noto SC, device
PingFang). Half-lead 4.7 + tracking 1.42/1.02 unchanged. Discs/far stay.
Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-1929 residual (after `58c138a46`):**
Watch scored the live tip (`58c138a46`, 02=`e2b09bfc`) and still rejected
craft vs PingFang Medium. Keep real Medium/Semibold cuts. Stem stays **0**.
Do not pile half-lead/tracking and do not revive Noto Bold. Title↔subtitle
gap **2 → 4** (`mt-1` after Medium ate `gap-0.5`); row visual **58.8 → 60.8**.
Dock/header visual stroke **0.36 → 0.32** (23px box stays). Project leading
**28 → 26**, schedule status **18 → 16** (glyph 8 → 7); hit 38 stays. Far
quieter official-black **3% / tight 2%**. Recapture 02 family after this dart;
04 MAE stayed tester-noise (~0.05) so those frames were restored.
**Not 精致.**

**2026-09-04 wake-1942 residual (after `49be39814`):**
Watch scored the live tip (`49be39814`, 02=`48fe99ba`) and still rejected
craft vs PingFang Medium. Stem stays **0**. Do not pile half-lead/tracking
or revive Noto Bold. Title↔subtitle gap **4 → 6** (Medium still ate `mt-1`);
row visual **60.8 → 62.8**. Dock/header visual stroke **0.32 → 0.28**
(23px box stays). Far back to official-soft black **4% / tight 2.5%**
(3%/2% read flat vs README lift; cream still cannot take official 10%).
Recapture 02 family after this dart; 04 MAE stayed tester-noise (~0.03)
so those frames were restored.
**Not 精致.**

**2026-09-04 wake-1951 residual (after `61baa11f0`):**
Watch scored the live tip (`61baa11f0`, 02=`ae1c004f`) and still rejected
craft vs PingFang Medium. Stem stays **0**. Do not pile half-lead/tracking
or revive Noto Bold. Title↔subtitle gap **6 → 8** (Medium still ate 6);
row visual **62.8 → 64.8**. Dock/header visual stroke **0.28 → 0.24**
(23px box stays). Far true-black **6% / tight 3.5%** (4%/2.5% still flat
vs README lift; cream still cannot take official 10%; trio geometry stays).
Recapture 02 family after this dart; 04 light MAE~0.16 kept (far/lift).
**Not 精致.**

**2026-09-04 wake-2001 residual (after `24b38c64f`):**
Watch scored the live tip (`24b38c64f`, 02=`9dabecc7`) and still rejected
craft vs PingFang Medium. Stem stays **0**. Do not pile half-lead/tracking
or revive Noto Bold. Title↔subtitle gap **8 → 10**; row **64.8 → 66.8**.
Project/schedule title↔meta **4 → 6**. Dock/header stroke **0.24 → 0.20**
(23px box stays). Far true-black **8% / tight 4.5%** (trio geometry stays;
no Material umbra). Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2009 residual (after `17a60638b`):**
Watch scored the live tip (`17a60638b`, 02=`c30e0c73`) and still rejected
craft vs official `mobile_projects.png` / `mobile_schedules.png` (ignore
palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not pile
half-lead, tracking, or Bold. Title↔subtitle gap **10 → 12**; row
**66.8 → 68.8**. Project/schedule title↔meta **6 → 8**. Dock/header
stroke **0.20 → 0.16** (23px box stays). Leading **26 → 24**, schedule
status **16 → 14** (glyph 7 → 6); hit 38 stays. Far official-black
**10% / tight 6%** (trio geometry stays; no Material umbra). Recapture
02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2020 residual (after `846d9a6b4`):**
Watch scored the live recapture (`846d9a6b4`, 02=`746ad416`) and still
rejected craft vs official `mobile_projects.png` / `mobile_schedules.png`
(ignore palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not
pile half-lead, tracking, or Bold. Title↔subtitle gap **12 → 14**; row
**68.8 → 70.8** (gap residual, not 7.5/70). Project/schedule title↔meta
**8 → 10**. Stroke stays **0.16** (official medium is 2; 23px box stays).
Search/header glyph **14 → 16** (official `size-4`, toward `size-5` 20;
36 plate / 40 `+` stay). Far stays official **10%** for project and
schedule (tight near pair only; no Material umbra). Recapture 02/04
after this dart.
**Not 精致.**

**2026-09-04 wake-2031 residual (after `890b3fe85`):**
Watch scored the live recapture (`890b3fe85`, 02=`6911d516`) and still
rejected craft vs official `mobile_projects.png` / `mobile_schedules.png`
(ignore palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not
pile half-lead, tracking, or Bold. Title↔subtitle gap **14 → 16**; row
**70.8 → 72.8** (gap residual, not 7.5/70). Project/schedule title↔meta
**10 → 12**. Dock/header stroke **0.16 → 0.12** (23px box stays; search
glyph 16 / 36 plate / 40 `+` stay). Far stays official **10%** (no
Material umbra). Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2040 residual (after `ab78b4cc1`):**
Watch scored the live recapture (`ab78b4cc1`, 02=`561f9c36`) and still
rejected craft vs official `mobile_projects.png` / `mobile_schedules.png`
(ignore palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not
pile half-lead, tracking, or Bold. Title↔subtitle gap **16 → 18**; row
**72.8 → 74.8** (gap residual, not 7.5/70). Project/schedule title↔meta
**12 → 14**. Search/header glyph **16 → 14**; leading plate **24 → 22**
(glyph 14 → 12); schedule status **14 → 12** (glyph 6 → 5); hit 38 /
23px dock / 36 plate / 40 `+` stay. Stroke stays **0.12**. Far stays
official **10%**; soften blur/spread **24/-6 → 32/-8** (no Material
umbra). `headerRestPeek` 0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2047 residual (after `bb01c23cd`):**
Watch scored the live recapture (`bb01c23cd`, 02=`cf11a303`) and still
rejected craft vs official `mobile_projects.png` / `mobile_schedules.png`
(ignore palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not
pile half-lead, tracking, or Bold. Title↔subtitle gap **18 → 20**; row
**74.8 → 76.8** (gap residual, not 7.5/70). Project/schedule title↔meta
**14 → 16**. Title↔first-card `pageProjectGap` **20 → 24** (official
`gap-6`; not a restPeek pull, not a fake banner). Search/header glyph
**14 → 12**; leading plate **22 → 20** (glyph 12 → 10); schedule status
**12 → 10** (glyph 5 → 4); hit 38 / 23px dock / 36 plate / 40 `+` stay.
Stroke stays **0.12**. Far stays official **10%**; soften blur/spread
**32/-8 → 40/-10** (no Material umbra). `headerRestPeek` 0. Recapture
02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2101 residual (after `b9f933ed2`):**
Watch scored the live recapture (`b9f933ed2`, 02=`b8217745`) and still
rejected craft vs official `mobile_projects.png` / `mobile_schedules.png`
(ignore palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not
pile half-lead, tracking, or Bold. Title↔subtitle gap **20 → 22**; row
**76.8 → 78.8** (gap residual, not 7.5/70). Project/schedule title↔meta
**16 → 18**. `pageProjectGap` stays **24** (official `gap-6`; not a
restPeek pull, not a fake banner). Search/header glyph **12 → 10**;
leading plate **20 → 18** (glyph 10 → 9); schedule status **10 → 8**
(glyph 4 → 3); hit 38 / 23px dock / 36 plate / 40 `+` stay. Stroke
stays **0.12**. Far stays official **10%**; soften blur/spread
**40/-10 → 48/-12** (no Material umbra). `headerRestPeek` 0. Recapture
02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2114 residual (after `31c6b5da6`):**
Watch scored the live recapture (`31c6b5da6`, 02=`e95db89b`) and still
rejected craft vs official `mobile_projects.png` / `mobile_schedules.png`
(ignore palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not
pile half-lead, tracking, or Bold. Title↔subtitle gap **22 → 24**; row
**78.8 → 80.8** (gap residual, not 7.5/70). Project/schedule title↔meta
**18 → 20**. `pageProjectGap` stays **24** (official `gap-6`; not a
restPeek pull, not a fake banner). Search/header glyph **10 → 8**;
leading plate **18 → 16** (glyph 9 → 8); schedule status **8 → 6**
(glyph 3 → 2); hit 38 / 23px dock / 36 plate / 40 `+` stay. Stroke
stays **0.12**. Far stays official **10%**; soften blur/spread
**48/-12 → 56/-14** (no Material umbra). `headerRestPeek` 0. Recapture
02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2127 residual (after `f99bb2951`):**
Watch scored the live recapture (`f99bb2951`, 02=`2428b7fe`) and still
rejected craft vs official `mobile_projects.png` / `mobile_schedules.png`
(ignore palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not
pile half-lead, tracking, or Bold. Title↔subtitle gap **24 → 26**; row
**80.8 → 82.8** (gap residual, not 7.5/70). Project/schedule title↔meta
**20 → 22**. `pageProjectGap` stays **24** (official `gap-6`; not a
restPeek pull, not a fake banner). Search/header glyph **8 → 6**;
leading plate **16 → 14** (glyph 8 → 7); schedule status **6 → 5**
(glyph 2 stays); hit 38 / 23px dock / 36 plate / 40 `+` stay. Stroke
stays **0.12**. Far stays official **10%**; soften blur/spread
**56/-14 → 64/-16** (no Material umbra). `headerRestPeek` 0. Recapture
02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2138 residual (after `33960892f`):**
Watch scored the live recapture (`33960892f`, 02=`07298259`) and still
rejected craft vs official `mobile_projects.png` / `mobile_schedules.png`
(ignore palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not
pile half-lead, tracking, or Bold. Title↔subtitle gap **26 → 28**; row
**82.8 → 84.8** (gap residual, not 7.5/70). Project/schedule title↔meta
**22 → 24**. `pageProjectGap` stays **24** (main `gap-5` is 20; official
`gap-6`; not a restPeek pull, not a fake banner). Search/header glyph
**6 → 5**; leading plate **14 → 12** (glyph 7 → 6); schedule status
**5 → 4** (glyph 2 stays); hit 38 / 23px dock / 36 plate / 40 `+` stay.
Stroke stays **0.12**. Far stays official **10%**; soften blur/spread
**64/-16 → 72/-18** (no Material umbra). `headerRestPeek` 0. Recapture
02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2145 residual (after `ad533d871`):**
Watch scored the live recapture (`ad533d871`, 02=`4b5d3112`) and still
rejected craft vs official `mobile_projects.png` / `mobile_schedules.png`
(ignore palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not
pile half-lead, tracking, or Bold. Title↔subtitle gap **28 → 30**; row
**84.8 → 86.8** (gap residual, not 7.5/70). Project/schedule title↔meta
**24 → 26**. `pageProjectGap` stays **24**. Search/header glyph stays
**5**; leading plate **12 → 10** (glyph 6 → 5); schedule status **4** /
glyph **2** stay; hit 38 / 23px dock / 36 plate / 40 `+` stay. Stroke
stays **0.12**. Far stays official **10%**; soften blur/spread
**72/-18 → 80/-20** (no Material umbra). `headerRestPeek` 0. Recapture
02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2152 residual (after `9e7962554`):**
Watch scored the live recapture (`9e7962554`, 02=`35d27f67`) and still
rejected craft vs official `mobile_projects.png` / `mobile_schedules.png`
(ignore palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not
pile half-lead, tracking, or Bold. Title↔subtitle gap **30 → 32**; row
**86.8 → 88.8** (gap residual, not 7.5/70). Project/schedule title↔meta
**26 → 28**. `pageProjectGap` stays **24**. Search/header glyph stays
**5**; leading plate **10 → 8** (glyph 5 → 4); schedule status **4** /
glyph **2** stay; hit 38 / 23px dock / 36 plate / 40 `+` stay. Stroke
stays **0.12**. Far stays official **10%**; soften blur/spread
**80/-20 → 88/-22** (no Material umbra). `headerRestPeek` 0. Recapture
02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2202 residual (after `1abb411d0`):**
Watch scored the live recapture (`1abb411d0`, 02=`6c75c6cc`) and still
rejected craft vs official `mobile_projects.png` / `mobile_schedules.png`
(ignore palette). Stem stays **0**. Keep Noto/PingFang Medium. Do not
pile half-lead, tracking, or Bold. Title↔subtitle gap **32 → 34**; row
**88.8 → 90.8** (gap residual, not 7.5/70). Project/schedule title↔meta
**28 → 30**. `pageProjectGap` stays **24**. Search/header glyph stays
**5**; leading plate **8 → 6** (glyph 4 → 3); schedule status **4** /
glyph **2** stay; hit 38 / 23px dock / 36 plate / 40 `+` stay. Stroke
stays **0.12**. Far stays official **10%**; soften blur/spread
**88/-22 → 96/-24** (no Material umbra). `headerRestPeek` 0. Recapture
02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2210 P0 recapture (dart `0748b11c5`):**
Large-title 空档 is universal for 项目 / 助理 / 计划 / 设置. Shared
`MobileTabPageScaffold` keeps the official expand-shift spacer
(10) plus `--oc-mobile-page-gap` (20) after `layoutSlot`.
`headerRestPeek` stays **0** — no per-tab peek / negative translate.
`pageProjectGap` stays card-stack only (Projects leading gap removed).
Recaptured 02 (+scrolled/dark) 03 04 (+dark) 05. 01/06/07/08 + 05-dark
restored (MAE ≤ 0.12).
**Not 精致.**

**2026-09-04 wake-2214 residual (after `2287afe9c`):**
Watch scored stale `bf95dea16` (02=`21811f8c`). Stay on tip. Stem
stays **0**. Keep Noto/PingFang Medium. Do not pile half-lead,
tracking, or Bold. Title↔subtitle gap **34 → 36**; row **90.8 → 92.8**
(gap residual, not 7.5/70). Project/schedule title↔meta **30 → 32**.
`pageProjectGap` stays **24**. Shared title 空档 stays expand-shift 10
+ page-gap 20. Search/header glyph stays **5**; leading plate **6 → 4**
(glyph 3 → 2); compact plate **4 → 2**; schedule status **4** / glyph
**2** stay; hit 38 / 23px dock / 36 plate / 40 `+` stay. Stroke stays
**0.12**. Far stays official **10%**; soften blur/spread
**96/-24 → 104/-26** (no Material umbra). `headerRestPeek` 0. Recapture
02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2222 residual (after `f6240a58f`):**
Watch scored unread `2287afe9c` (02=`475c284c`). Stay on tip. Stem
stays **0**. Keep Noto/PingFang Medium. Do not pile half-lead,
tracking, or Bold. Title↔subtitle gap **36 → 38**; row **92.8 → 94.8**
(gap residual, not 7.5/70). Project/schedule title↔meta **32 → 34**.
`pageProjectGap` stays **24**. Shared title 空档 stays expand-shift 10
+ page-gap 20. Search/header glyph stays **5**; leading plate **4 → 2**
(glyph **2** stays); compact **2**; schedule status **4 → 2** / glyph
**2**; hit 38 / 23px dock / 36 plate / 40 `+` stay. Stroke stays
**0.12**. Far stays official **10%**; soften blur/spread
**104/-26 → 112/-28** (no Material umbra). `headerRestPeek` 0.
Recapture 02 (+scrolled/dark) 03 04 (+dark) 05 after this dart.
**Not 精致.**

**2026-09-04 wake-2227 residual (after `ba7b62678`):**
Watch scored dart-only `8a6b097fb` + unread `f6240a58f`
(`02=b7ae61bc`). Stay on tip. Stem stays **0**. Keep Noto/PingFang
Medium. Do not pile half-lead, tracking, or Bold. Title↔subtitle
gap **38 → 40**; row **94.8 → 96.8** (gap residual, not 7.5/70).
Project/schedule title↔meta **34 → 36**. `pageProjectGap` stays **24**.
Shared title 空档 stays expand-shift 10 + page-gap 20. Search/header
glyph stays **5**; leading/status plates stay **2** (hit 38); glyphs
**2 → 1** so the 2px plate is not a filled coin. Stroke stays **0.12**.
Far stays official **10%**; soften blur/spread **112/-28 → 120/-30**
(no Material umbra). `headerRestPeek` 0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2231 residual (after `9dcffde10`):**
Watch scored dart-only `d1e204167` + unread `ba7b62678`
(`02=dbaa15b2`). Stay on tip. Stem stays **0**. Keep Noto/PingFang
Medium. Do not pile half-lead, tracking, or Bold. Title↔subtitle
gap **40 → 42**; row **96.8 → 98.8** (gap residual, not 7.5/70).
Project/schedule title↔meta **36 → 38**. `pageProjectGap` stays **24**.
Shared title 空档 stays expand-shift 10 + page-gap 20. Search/header
glyph stays **5**; leading/status plates stay **2** (hit 38); glyphs
stay **1**. Stroke stays **0.12**. Far stays official **10%**; soften
blur/spread **120/-30 → 128/-32** (no Material umbra). `headerRestPeek`
0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2235 residual (after `1dd5710fb`):**
Watch scored live tip `1dd5710fb` (02=`308856fd`). Stay on tip.
Stem stays **0**. Keep Noto/PingFang Medium. Do not pile half-lead,
tracking, or Bold. Title↔subtitle gap **42 → 44**; row **98.8 → 100.8**
(gap residual, not 7.5/70). Project/schedule title↔meta **38 → 40**.
`pageProjectGap` stays **24**. Shared title 空档 stays expand-shift 10
+ page-gap 20. Search/header glyph stays **5**; leading/status plates
stay **2** (hit 38); glyphs stay **1**. Stroke stays **0.12**. Far
stays official **10%**; soften blur/spread **128/-32 → 136/-34**
(no Material umbra). `headerRestPeek` 0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2241 residual (after `9d1b6eb3e`):**
Watch scored dart-only `b2bae5584` + unread `1dd5710fb`
(`02=308856fd`). Stay on tip. Stem stays **0**. Keep Noto/PingFang
Medium. Do not pile half-lead, tracking, or Bold. Title↔subtitle
gap **44 → 46**; row **100.8 → 102.8** (gap residual, not 7.5/70).
Project/schedule title↔meta **40 → 42**. `pageProjectGap` stays **24**.
Shared title 空档 stays expand-shift 10 + page-gap 20. Search/header
glyph stays **5**; leading/status plates stay **2** (hit 38); glyphs
stay **1**. Stroke stays **0.12**. Far stays official **10%**; soften
blur/spread **136/-34 → 144/-36** (no Material umbra). `headerRestPeek`
0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2246 residual (after `834ee5d78`):**
Watch scored dart-only `4230d7f02` + unread `9d1b6eb3e`
(`02=c958c1f9`). Stay on tip. Stem stays **0**. Keep Noto/PingFang
Medium. Do not pile half-lead, tracking, or Bold. Title↔subtitle
gap **46 → 48**; row **102.8 → 104.8** (gap residual, not 7.5/70).
Project/schedule title↔meta **42 → 44**. `pageProjectGap` stays **24**.
Shared title 空档 stays expand-shift 10 + page-gap 20. Search/header
glyph stays **5**; leading/status plates stay **2** (hit 38); glyphs
stay **1**. Stroke stays **0.12**. Far stays official **10%**; soften
blur/spread **144/-36 → 152/-38** (no Material umbra). `headerRestPeek`
0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2250 residual (after `05ac8692c`):**
Watch scored dart-only `a452effa4` + unread `834ee5d78`
(`02=def446a4` class). Stay on tip. Stem stays **0**. Keep Noto/PingFang
Medium. Do not pile half-lead, tracking, or Bold. Title↔subtitle
gap **48 → 50**; row **104.8 → 106.8** (gap residual, not 7.5/70).
Project/schedule title↔meta **44 → 46**. `pageProjectGap` stays **24**.
Shared title 空档 stays expand-shift 10 + page-gap 20. Search/header
glyph stays **5**; leading/status plates stay **2** (hit 38); glyphs
stay **1**. Stroke stays **0.12**. Far stays official **10%**; soften
blur/spread **152/-38 → 160/-40** (no Material umbra). `headerRestPeek`
0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2259 residual (after `a7e34e2fb`):**
Watch scored live `a7e34e2fb` / `02=8223e266`. Stay on tip.
Stem stays **0**. Keep Noto/PingFang Medium. Do not pile half-lead,
tracking, or Bold. Title↔subtitle gap **50 → 52**; row **106.8 → 108.8**
(gap residual, not 7.5/70). Project/schedule title↔meta **46 → 48**.
`pageProjectGap` stays **24**. Shared title 空档 stays expand-shift 10 +
page-gap 20. Search/header glyph stays **5**; leading/status plates stay
**2** (hit 38); glyphs stay **1**. Stroke stays **0.12**. Far stays
official **10%**; soften blur/spread **160/-40 → 168/-42** (no Material
umbra). `headerRestPeek` 0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2310 residual (after `dab8cbf28`):**
Watch scored live `dab8cbf28` / `02=9e96ab70`. Stay on tip.
Stem stays **0**. Keep Noto/PingFang Medium. Do not pile half-lead,
tracking, or Bold. Title↔subtitle gap **52 → 54**; row **108.8 → 110.8**
(gap residual, not 7.5/70). Project/schedule title↔meta **48 → 50**.
`pageProjectGap` stays **24**. Shared title 空档 stays expand-shift 10 +
page-gap 20. Search/header glyph stays **5**; leading/status plates stay
**2** (hit 38); glyphs stay **1**. Stroke stays **0.12**. Far stays
official **10%**; soften blur/spread **168/-42 → 176/-44** (no Material
umbra). `headerRestPeek` 0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2317 residual (after `ea7d7e170`):**
Watch scored live `ea7d7e170` / `02=d2002cfc`. Stay on tip.
Stem stays **0**. Keep Noto/PingFang Medium. Do not pile half-lead,
tracking, or Bold. Title↔subtitle gap **54 → 56**; row **110.8 → 112.8**
(gap residual, not 7.5/70). Project/schedule title↔meta **50 → 52**.
`pageProjectGap` stays **24**. Shared title 空档 stays expand-shift 10 +
page-gap 20. Search/header glyph stays **5**; leading/status plates stay
**2** (hit 38); glyphs stay **1**. Stroke stays **0.12**. Far stays
official **10%**; soften blur/spread **176/-44 → 184/-46** (no Material
umbra). `headerRestPeek` 0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2325 residual (after `7949be319`):**
Watch scored live `7949be319` / `02=9206b388`. Stay on tip.
Stem stays **0**. Keep Noto/PingFang Medium. Do not pile half-lead,
tracking, or Bold. Title↔subtitle gap **56 → 58**; row **112.8 → 114.8**
(gap residual, not 7.5/70). Project/schedule title↔meta **52 → 54**.
`pageProjectGap` stays **24**. Shared title 空档 stays expand-shift 10 +
page-gap 20. Search/header glyph stays **5**; leading/status plates stay
**2** (hit 38); glyphs stay **1**. Stroke stays **0.12**. Far stays
official **10%**; soften blur/spread **184/-46 → 192/-48** (no Material
umbra). `headerRestPeek` 0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2332 residual (after `bae67524d`):**
Watch scored live `bae67524d` / `02=ce3b64a4`. Stay on tip.
Do **not** pile another +2 title↔meta air (loop exhausted). Gap stays
**58**; row **114.8**; title↔meta **54**. Stem stays **0**. Do not pile
half-lead, tracking, or Bold. Plates stay **2**; glyphs stay **1**;
header glyph stays **5**; stroke stays **0.12**. Far stays official
**10%** black; restore official geometry **192/-48 → 24/-6** so cream
cards match `--oc-mobile-float-shadow` lift (the widen loop ate the
umbra). `headerRestPeek` 0. Shared spacer 10 + page-gap 20. Recapture
02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2341 residual (after `9d90423f4`):**
Watch scored live `9d90423f4` / `02=500c3fb9`. Stay on tip.
Do **not** pile another +2 title↔meta air. Gap stays **58**; row
**114.8**; title↔meta **54**. Stem stays **0**. Do not pile half-lead,
tracking, or Bold. Far stays official **10/24/-6** at **10%**. Restore
shrink-to-death icon optics vs README `mobile_projects.png` /
`mobile_schedules.png`: search glyph **5 → 12**; small-chrome stroke
**0.12 → 0.45** (dock 23px stays **0.12**); leading/status plates
**2 → 28**; leading/status glyphs **1 → 14**; worktree compact box
**2 → 18** (official). Settings nav stays dock **0.12**. `headerRestPeek`
0. Shared spacer 10 + page-gap 20. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-2356 residual (after `e33600291`):**
Watch scored live `e33600291` / `02=573f3c9b`. Stay on tip.
Do **not** pile another +2 title↔meta air (re-kills icon
alignment). Gap stays **58**; row **114.8**; title↔meta **54**.
Plates stay **28**; glyphs stay **14**. Far stays official
**10/24/-6** at **10%**. Tune toward README without ballooning:
search glyph **12 → 14**; small-chrome stroke **0.45 → 0.62**
(dock 23px stays **0.12**); project / schedule rows
`CrossAxisAlignment.start` so 28 discs sit on the title row
instead of the 54 air gap. Settings nav stays dock **0.12**.
`headerRestPeek` 0. Recapture 02/04 after this dart.
**Not 精致.**

**2026-09-04 wake-0008 residual (after `9f080513c`):**
Watch scored live `9f080513c` / `02=8ce0b5b2`. Stay on tip.
Do **not** pile +2 air. Gap stays **58**; meta **54**; plates **28**;
glyphs **14**; search **14**; small-chrome stroke **0.62**; dock
**0.12**; far **10/24/-6**. Title-row start-align stays. Session rows
`CrossAxisAlignment.start` so time / ··· sit on the title band (not
the 114.8 air). Unread titles official `font-semibold` (w600; review
CJK snaps to Medium). Session more **12 → 14** (`size-3.5`); trailing
··· / chevron use dock **0.12** (not 0.62 meatballs). Recapture 02/04
after this dart.
**Not 精致.**

**2026-09-04 wake-0023 residual (after `a8ab35d83`):**
Watch scored live `a8ab35d83` / `02=69fbcebe`. Stay on tip.
Do **not** pile +2 project/schedule title↔meta air (re-kills icon
alignment). Meta stays **54**. Plates **28**; glyphs **14**; search
**14**; small-chrome stroke **0.62**; dock **0.12**; far official
**10/24/-6** at **10%**. Session start-align + unread semibold +
more 14 stay. Gently reduce session title↔subtitle residual air
**58 → 52** (widen loop left rows too airy vs `mobile_projects.png`);
row **114.8 → 108.8**. Do not jump to official `gap-0.5` (2). Do not
shrink plates/search/stroke. `headerRestPeek` 0; expand-shift 10 +
page-gap 20. Recapture 02 (+scrolled/dark) after this dart.
**Not 精致.**

**2026-09-04 wake-0037 residual (after `a92e74344`):**
Watch scored live `a92e74344` / `02=2979f0d2`. Stay on tip.
Do **not** re-widen. Do **not** pile +2 project/schedule title↔meta
(meta **54** stays). Plates **28**; glyphs **14**; search **14**;
small-chrome stroke **0.62**; dock **0.12**. Session start-align +
unread semibold + more 14 stay. Tighten session title↔subtitle
**52 → 46** (still airy vs README); row **108.8 → 102.8**. Far stays
official **10/24** at **10%** black; WidgetTester spread **-6 → -2**
so the umbra sits under the card (not Material 8/20, not 192/-48).
`headerRestPeek` 0; expand-shift 10 + page-gap 20. Recapture 02
(+scrolled/dark; 04 if far MAE > ~0.12) after this dart.
**Not 精致.**

**2026-09-04 wake-0052 residual (after `aaad24d5f`):**
Watch scored live `aaad24d5f` / `02=27e10a57`. Stay on tip.
Do **not** re-widen. Do **not** pile +2 project/schedule title↔meta
(meta **54** stays). Plates **28**; glyphs **14**; search **14**;
small-chrome stroke **0.62**; dock **0.12**. Session start-align +
unread semibold + more 14 stay. Far stays official **10/24** at
**10%** with WidgetTester spread **-2**. Tighten session
title↔subtitle **46 → 40** toward README type density (official
column still `gap-0.5`); row **102.8 → 96.8**. Do not jump to 2.
`headerRestPeek` 0; expand-shift 10 + page-gap 20. Recapture 02
(+scrolled/dark; 04 if unchanged leave it) after this dart.
**Not 精致.**

**2026-09-04 wake-0106 residual (after `7f45f8da0`):**
Watch scored live `7f45f8da0` / `02=8bceb39c`. Stay on tip.
Do **not** re-widen. Do **not** pile +2 project/schedule title↔meta
(meta **54** stays). Plates **28**; glyphs **14**; search **14**;
small-chrome stroke **0.62**; dock **0.12**. Far stays official
**10/24** at **10%** with WidgetTester spread **-2** (no Material
umbra). Session start-align + unread semibold + more 14 stay.
Tighten session title↔subtitle **40 → 34** toward README density
(official column still `gap-0.5`; do not jump to 2); row
**96.8 → 90.8**. `headerRestPeek` 0; expand-shift 10 + page-gap 20.
Recapture 02 (+scrolled/dark; 04 only if schedule rows change).
**Not 精致.**

**2026-09-04 wake-0114 residual (after `873e00eb7`):**
Watch scored live `873e00eb7` / `02=35edbf86`. Stay on tip.
Do **not** re-widen. Do **not** pile +2 project/schedule title↔meta
(meta **54** stays). Plates **28**; glyphs **14**; search **14**;
small-chrome stroke **0.62**; dock **0.12**. Far stays official
**10/24** at **10%** with WidgetTester spread **-2** (no Material
umbra). Session start-align + unread semibold + more 14 stay.
Tighten session title↔subtitle **34 → 28** toward README density
(official column still `gap-0.5`; do not jump to 2); row
**90.8 → 84.8**. `headerRestPeek` 0; expand-shift 10 + page-gap 20.
Recapture 02 (+scrolled/dark; 04 only if schedule rows change).
**Not 精致.**

**2026-09-04 wake-0123 residual (after `c1a4e06aa`):**
Yee 01:23 CST: spacing still wrong. Two real knobs — stop the
session-air inflate loop. Large-title 空档 was **30** vs official
**20 + 10 + 20 = 50**. Session title↔subtitle **28 → 2**; row
**84.8 → 58.8**. Recapture 02/03/04/05.
**Not 精致.**

**2026-09-04 wake-0135 residual (after `a9480cc11`):**
Watch scored live `a9480cc11` / `02=8144be73`. STRUCTURE PASS.
Do **not** undo 20+10+20 or session gap **2**. Plates **28**; glyphs
**14**; search **14**; stroke **0.62**; dock **0.12**; session
start-align; unread semibold; more 14. Project/schedule title↔meta
was the same invented inflate as the old session gap — reset
**54 → 4** (official `gap-1` / `mt-1`). Restore project/schedule
`items-center`. Do not re-widen. Recapture 02 (+scrolled/dark) and
04 (+dark).
**Not 精致.**

**2026-09-04 wake-0139 residual (after `472a49fed`):**
Delayed score of `a9480cc`. Live tip already has meta **4** +
session gap **2** + title band **20+10+20**. Card internal padding
is already official (row 5 / trigger 10 / groups 2·12·14 /
schedule 12). Do **not** invent tighter pad. Do **not** pile
half-lead/tracking. Do **not** nibble plates **28** / glyphs **14**
/ search **14** / stroke **0.62** / dock **0.12**. Restore official
float far spread **-2 → -6** (`0 10px 24px -6px` / 10%) so
schedule + project umbra match `MobileFloatingSurface`, not a
WidgetTester loudness knob. Recapture 02 (+scrolled/dark) and 04
(+dark).
**Not 精致.**

**2026-09-04 wake-0143 residual (after `abb2a93a4`):**
Watch scored stale `472a49fed` / `02=17c0188b`. Live tip already
has official far **-6**. Title↔meta token is **4** but project /
schedule meta `OcCssLine` still used default half-lead **4.7**, so
official `gap-1` / `mt-1` never landed. Meta now `halfLead: 0`
(official 12/15 box). Do **not** re-inflate to 54. Do **not** undo
20+10+20 or session gap **2**. Icons 28/14/14/0.62/0.12 stay.
Recapture 02 (+scrolled/dark) and 04 (+dark).
**Not 精致.**

**2026-09-04 wake-0148 residual (after `bede83455`):**
Watch scored stale `abb2a93a4` / `02=17c0188b`. Live tip already
has meta `halfLead: 0` and far **-6**. Session subtitle/time still
used default 4.7 and invented a taller-than-official 10/12 box.
Subtitle/time now official 10/12 (`sessionSubtitleHalfLead` 0);
title stays 16/12 + 4.7. Row **58.8 → 49.4**. Do **not** undo
20+10+20, session gap **2**, title↔meta **4**. Icons 28/14/14/0.62/0.12
stay. Recapture 02 (+scrolled/dark).
**Not 精致.**

**2026-09-04 wake-0152 residual (after `7c8112a0e`):**
Watch scored stale `bede83455` / `02=1e4f4546`. Live tip already
has session subtitle/time official 10/12 (row 49.4). Do **not**
undo 20+10+20, session gap **2**, title↔meta **4**, meta
`halfLead: 0`. Search/+/dock stay 14/40/0.62/0.12 — no Flutter
glass clone. Schedule check/pause stroke **0.62 → 0.12** (same
slim medium as schedule `more-2`). Far stays official **-6**.
Recapture 04 (+dark).
**Not 精致.**

| File | Screen |
|---|---|
| `01-connect.png` | QR primary, inset grouped fields (no floating-label overlap). |
| `02-projects.png` | Light: catalog sand/orange. Overlay collapsing header. Large title ↔ first card uses shared 20+10+20 (not a restPeek pull; `pageProjectGap` is card-stack after that). One project shell: header + padded session/worktree groups. |
| `02-projects-scrolled.png` | Same Projects list jumped just past the official 48px collapse. Title is compact; cards stay visible under the translucent header (not an emptied mid-scroll). |
| `02-projects-dark.png` | Same Projects surface after Appearance → Dark (catalog `OcTokens`, not a photo recolor). |
| `03-assistant.png` | Contact cards (name / mode / summary). Shared title 空档 (20+10+20). No 「启用助理」 toggle. |
| `04-scheduled.png` | Light: catalog tokens. Shared title 空档 (20+10+20). Quiet schedule status discs. Soft float cards. Dock 计划 uses the official calendar grid (filled plate + date holes, not calendar-clock). |
| `04-scheduled-dark.png` | Same Scheduled surface after Appearance → Dark. |
| `05-settings.png` | Large title, pill search, inset groups. Shared title 空档 (20+10+20). |
| `06-settings-appearance.png` | Light: language + theme. Latin labels must render. No `iosNativeUi`. |
| `06-settings-appearance-dark.png` | Appearance after tapping Dark — tokens switch live. |
| `07-chat.png` | Isolated pushed Chat (light): official 1.625 transcript leading, 40px glass chips, centered title, official attach `size-5`, last-turn footer meta (copy / fork / tok/s / duration / clock), one “已处理”, folded file marks + `+N/-M`. Not UIKit glass. |
| `07-chat-dark.png` | Same isolated Chat with `ThemeMode.dark`. |
| `07-chat-activity.png` | Expanded 「已处理」 activity: gap under header, skill + terminal rows, foreground ink, OcGlyph folder/`>_`/chevron. |
| `08-permission.png` | Permission card only. |
