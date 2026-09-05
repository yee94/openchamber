# Flutter native screenshots (Yee visual review)

Real `apps/mobile_flutter` widgets, captured with `WidgetTester` + `RenderRepaintBoundary.toImage`.

- Device: **390×844** logical pixels, `devicePixelRatio` **3** (PNG 1170×2532)
- Locale: **zh-CN**
- Regenerator: `apps/mobile_flutter/test/flutter_native_screenshots_test.dart`
- Fonts: `test/review_fonts.dart` loads Roboto Regular+Medium. CJK Regular stays WenQuanYi Micro Hei; **Noto Sans CJK SC DemiLight** loads when `fonts-noto-cjk-extra` is present (SC face from the TTC, remapped to usWeightClass 500) so official `font-medium` / `font-semibold` titles match PingFang Medium optical weight — not Noto Medium (bricks 12px / 32px), not a miter stem, not Regular clamped to w400, not Noto Bold. Droid is last fallback. **Chrome icons are painted `OcGlyph` paths** — do not accept empty-square CupertinoIcons tofu.
- WidgetTester runs as Android. Official collapsing header is transparent plus fade-on-collapse only (no always-on frost plate). Dock uses clipped `BackdropFilter` through-plates (iOS 26 live chrome is UIKit `UIGlassEffect`; these PNGs cannot prove that). Search uses `OcGlassChip` through-frost (`glassChipThrough` 0.16, σ14, official saturate light 1.25 / dark 1.2, 34 plate — not a 0.34 cream coin, no near-pair halo, no 8/20 umbra, no 0.68 coin). Search / Projects `+` glyphs stay optical 14. Catalog / schedule discs keep `glassChipFill` 0.34. Solid `+` is official 40 primary. Chat / Settings detail-nav chips are official `mobileGlass` 40 + `glassFill` 0.68 + `size-5` (20) / stroke 1.5 (not catalog 14 / 0.28 — that vanished the 返回键 on sand). Project shells keep the official float-shadow trio — near pair (2 + 12) plus far 10/24/-6 as true black at official light 10% / dark 34% (`rgb(0 0 0 / 0.1)` / `0.34`; official `0 10px 24px -6px`, not a WidgetTester -2 loudness knob, not a darker Material umbra). Schedule cards use the same official `--oc-mobile-float-shadow` trio (no quieter near pair). Nested worktree groups keep the official 1px inset border, painted a hair darker so the shell reads on cream. No Material 8/20 umbra. Schedule status hit is official 38; painted plate is 24; glyph is 12 at dock stroke 1.25; plate is glassChipThrough + inset highlight (no OcGlassChip frost/chip shadow); schedule ellipsis is 10 at dock 1.25; scheduled-add is official ink (foreground disc). Project / schedule 14/18 titles use cardTitleHalfLead 3.0 (not session 4.7) on Regular CJK; live iOS uses the official CSS box. Dock plate fill is 0 on WidgetTester (cream fill always reads as a stadium). Frost is `blur(20) saturate(1.25/1.2)` + glass-shadow near-pair (2/12) so selected `/55` is a through-mix on the list, not a cream pill. Official `floatSurface` 0.45 is too solid here. Chat detail-nav chips stay official 40 `mobileIcon` frost discs (not 44 coins, not flat glyphs). Dock selected is mix-only `interactive-selection/55` (no hairline pill, no RGB@0.55, no nested frost). Session rows stay in the official ~40 class with title 3.2px CJK half-lead plus official title↔subtitle `gap-0.5`; subtitle/time stay the official 10/12 box (40 + 2×3.2 + 0 → 46.4 — not 7.5 half-lead / 70; default OcCssLine ceiling ~4.75). Session titles paint `ocCssInk` inside the 16/12 box + pinned 3.2 half-lead as official `font-medium` on the widget style; CJK fills Regular Micro Hei (DemiLight@500 still bricks 12px vs PingFang Medium air, no miter stem, no shade); Latin stays ReviewSans Medium at official −0.012em. Project titles use official `font-semibold` on the widget style and official −0.024em on Latin / live iOS; Regular CJK keeps 1.46 / 1.02 compensation. Collapsing page-title CJK is Regular Micro Hei at 32px (widget style stays `w600`). Stay under 1.5 / 1.1 on the Regular CJK knobs. Do not pile half-lead. Do not load Noto Medium or Bold for titles. Project-shell frost (`floatSurface` 0.45) sits behind that ink so 12px cores are not composited through the plate. Project / schedule 14/18 titles paint `ocCssInk` in the official CSS box plus cardTitleHalfLead 3.0 so Regular CJK is not packed; session 3.2 stays on 12px rows only. Review-face session/project/schedule titles keep official `w500`/`w600` on Latin; CJK fills Regular Micro Hei. Collapsing page-title CJK stays Regular. Do not load Noto Medium or Bold for titles. Dock labels stay Regular Micro Hei with 0 tracking so chrome CJK stays open. Project leading / search paint small-chrome stroke 0.28; search glyphs stay 14 and catalog disc glyphs are 12 so 28 plates are not cream coins at dpr 3; dock 23px / settings nav / session-more / schedule-ellipsis stay visual 1.25 (settings chevron 1.0). Folder / sparkles / calendar / gear all paint 23px at visual stroke 1.25. Composer is official `--surface-subtle` with no elevation / no frost; idle+ready send is official solid foreground `SendCircleIcon` (arrow-up, idle 0.55). File-type marks are stroke-only silhouettes at visual 1.0, not blue squares. Footer action stroke is 1.0. These PNGs cannot prove live iOS glass or 精致. Real iOS still keeps live glass on UIKit overlays. Mid-scroll proof: `02-projects-scrolled.png`. This Linux VM cannot run an iOS Simulator. Goldens reserve `viewPadding.top = 47` for the status area; they do **not** paint a fake UIKit status bar.
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

**2026-09-04 wake-0157 residual (after `2bfb542e0`):**
Watch scored live `2bfb542e0` / goldens `7c8112a0e` (`02=453ecf5a`).
STRUCTURE PASS. THEME OK. Do **not** undo 20+10+20, session gap
**2**, title↔meta **4**, subtitle/time `halfLead` **0**, title
half-lead 4.7. Do **not** pile tracking / half-lead. Plates **28**;
glyphs **14**; search **14**; header stroke **0.62**; dock **0.12**.
Far stays official **-6**. Worktree label still used session 12/16
Regular + default half-lead 4.7 and header 0.62 meatballs. Port
official project-shell `oc-mobile-entity-title` (14/18 + semibold +
cardTitleHalfLead 2.7), count `.typography-small` 11/14
(`halfLead: 0`), more/chevron dock **0.12**. Recapture 02
(+scrolled/dark).
**Not 精致.**

**2026-09-04 wake-0209 residual (after `4513e4e3f`):**
Watch scored live `4513e4e3f` / `02=a9a88511`. STRUCTURE PASS.
THEME OK. Do **not** undo worktree 14/18 + count 11/14, 20+10+20,
session gap **2**, title↔meta **4**, subtitle/time `halfLead` **0**.
Plates **28**; search/+/dock stay. Far stays official 10/24/-6 @
10% — do not invent Material umbra. Session title half-lead
**4.7 → 3.7** toward the official 16/12 box (row **49.4 → 47.4**).
Do not jump to 0. Recapture 02 (+scrolled/dark).
**Not 精致.**

**2026-09-04 wake-0218 residual (after `544d957b8`):**
Watch scored live `544d957b8` / `02=0f76637b`. STRUCTURE PASS.
THEME OK. Do **not** undo 3.7 box (row 47.4), gap **2**, 20+10+20,
title↔meta **4**, worktree 14/18, far **10/24/-6 @ 10%**. Plates
**28**; search/+/dock stay. No frost clone. Session title tracking
**1.42 → 1.46** so the 3.7 box does not pack Regular CJK. Stay
under 1.5. Recapture 02 (+scrolled/dark).
**Not 精致.**

**2026-09-04 wake-0228 residual (after `1e2a6be5a`):**
Watch scored live `1e2a6be5a` / `02=bf89adbc`. Tracking nudge
alone did not close craft. STRUCTURE PASS. THEME OK. Do **not**
undo 3.7 / 1.46, gap **2**, 20+10+20, title↔meta **4**, far
**10/24/-6**. Plates **28**; search/+/dock **hits** stay. No frost
clone. Small-chrome stroke **0.62 → 0.50** (search / leading
optical weight; not a hit-box grow). Session title half-lead
**3.7 → 3.2** toward official 16/12 (row **47.4 → 46.4**); gap-0.5
stays. Recapture 02 (+scrolled/dark) after `ca35d4e28`:
`02=744af68e` / scrolled `816c4b19` / dark `2b9a8856`. MAE vs
`1e2a6be5a` ~4.08 / 4.53 / 3.34. 03/04/05/07 SAME (`2dbec33b` /
`94805d37` / `6534068a` / `1db7adf7`).
**Not 精致.**

**2026-09-04 wake-0239 residual (after `dfca2cec9`):**
Watch scored live `dfca2cec9` / `02=744af68e`. STRUCTURE PASS.
THEME OK. Do **not** pile half-lead 3.2 or tracking 1.46. Do **not**
jump half-lead to 0. Gap **2**, 20+10+20, title↔meta **4**, far
**10/24/-6 @ 10%** stay. Plates **28**; glyphs **14**; hits **40**.
No frost clone. Port official `MobileSessionRow` `items-center`
(drop README-trace `start` from the 114.8-air era). Small-chrome
stroke **0.50 → 0.38** (search / leading optical weight; not a
hit-box grow, not a hairline). Recapture 02 (+scrolled/dark) after
`dbefa98ee`: `02=ed32cf05` / scrolled `80646f23` / dark `3756afa6`.
MAE vs `dfca2cec9` ~0.41 / 0.38 / 0.36. 03/04/05/07 SAME.
**Not 精致.**

**2026-09-04 wake-0247 residual (after `80e16e7c2`):**
Watch scored live `80e16e7c2` / `02=ed32cf05`. STRUCTURE PASS.
THEME OK. Session `items-center` stays — do **not** re-widen.
Do **not** pile session half-lead 3.2 or tracking 1.46. Do **not**
jump half-lead to 0. Gap **2**, 20+10+20, title↔meta **4**, far
**10/24/-6 @ 10%** stay. Plates **28**; glyphs **14**; hits **40**;
search plate **36**. No frost clone. Project / worktree / schedule
14/18 `cardTitleHalfLead` **2.7 → 3.0** (type air vs PingFang
Medium; not a session-row bump). Small-chrome stroke **0.38 → 0.28**.
Recapture 02 (+scrolled/dark) and 04 after `2896bbd38`:
`02=f493f9d6` / scrolled `a50c1d20` / dark `46822d2d`;
04 `77c1902c` / 04-dark `ddec1df2`. MAE vs `80e16e7c2` ~0.07 /
0.07 / 0.14 on 02; ~2.98 / 2.36 on 04. 03/05/07 SAME.
**Not 精致.**

**2026-09-04 wake-0257 residual (after `04783aa92`):**
Watch scored live `04783aa92` / `02=f493f9d6`. STRUCTURE PASS.
THEME OK. Do **not** pile session half-lead 3.2, card 3.0, tracking
1.46, or stroke 0.28. Do **not** re-widen. Do **not** nibble plates
**28** / glyphs **14**. Far stays official **10/24/-6 @ 10%**. Hits
**40**. `+` stays official 40. Search frost plate **36 → 34** (disc
scale; not the 32 vanish, not a glass clone). Recapture MAE vs
`04783aa92` ~0.004 / 0.004 / 0.09 — below tester noise; goldens
unrestored (`02=f493f9d6` / scrolled `a50c1d20` / dark `46822d2d`).
04 unrestored. WidgetTester cannot prove the 2px plate.
**Not 精致.**

**2026-09-04 wake-0308 residual (after `4d2fde05e`):**
Watch scored live `4d2fde05e` / `02=f493f9d6` (byte-identical to
wake-0257). STRUCTURE PASS. THEME OK. Plate 36→34 stays — do **not**
step to 32. Do **not** pile 3.2 / 3.0 / 1.46 / 0.28 / 28 / 14.
Far stays official **10/24/-6 @ 10%**. Noto Medium was already a
real w500 cut and still read tight vs PingFang Medium. Review title
face **Noto Medium → DemiLight@500** (PingFang Medium optical; not
a half-lead pile, not Regular clamp, not Noto Bold). Recapture after
`68dd39b57`: `02=cb525b1e` / scrolled `5f8943fc` / dark `1ab0d576`;
04 `c3f0753c` / 04-dark `75bd68be`. MAE vs `04783aa92` ~0.39 / 0.31
/ 0.39 on 02; ~0.53 / 0.43 on 04. 01/03/05/07 also moved (CJK
titles). Restored 06 + 07-activity (MAE ≤ 0.12). **Not 精致.**

**2026-09-04 wake-0321 residual (after `640063340`):**
Watch scored live `640063340` / `02=cb525b1e`. STRUCTURE PASS.
THEME OK. DemiLight@500 stays — do **not** flip Medium/Bold. Do
**not** pile session half-lead 3.2, card 3.0, tracking 1.46/1.02,
or search plate 34. Far stays official **10/24/-6 @ 10%**. Plates
**28**. Search glyph **14**. Catalog disc glyphs **14 → 12** then
small-chrome stroke **0.28 → 0.16**. Recapture MAE vs `640063340`
~0.006 / 0.005 / 0.005 on 02; ~0.019 / 0.012 on 04 — below tester
noise; goldens unrestored (`02=cb525b1e` / scrolled `5f8943fc` /
dark `1ab0d576`; 04 `c3f0753c` / 04-dark `75bd68be`). WidgetTester
cannot prove the 2px glyph or 0.12 stroke. Hits **40**. No frost
clone. **Not 精致.**

**2026-09-04 wake-0325 residual (after `640063340` / `31807cdfc`):**
Watch scored live DemiLight goldens `02=cb525b1e`. STRUCTURE PASS.
THEME OK. Type still tight/heavy at 32px DemiLight vs PingFang
Semibold air. Session/card titles stay DemiLight@500. Collapsing
page-title CJK paints Regular Micro Hei (`w400`) — not a Medium
flip, not a half-lead pile. Stroke back to official optical
**0.28**. Half-lead **3.2** / card **3.0** / tracking / plate **34**
/ far **10/24/-6 @ 10%** stay. Recapture after dart `18a0135f8`:
`02=3c3419a2` / scrolled `017f1cc6` / dark `0a56f7ba`;
03 `147da994`; 04 `25b842f5` / 04-dark `0e78a22e`;
05 `8d94356a` / 05-dark `13efae4d`. MAE vs `640063340`
~0.29 / 0.11 / 0.27 on 02; ~0.31 on 03; ~0.24 / 0.21 on 04;
~0.35 / 0.13 on 05. Restored 01 / 06 / 07 / 08 (MAE ≤ 0.11
except 01/08 SAME). Scrolled kept (same Regular title at
compact scale). **Not 精致.**

**2026-09-04 wake-0338 residual (after `977c77570` / `a6483822f`):**
Watch scored live Regular page-title goldens `02=3c3419a2`.
STRUCTURE PASS. THEME OK. Type still tight vs PingFang Medium
on 12px / 14px DemiLight@500. Session/card CJK fills Regular
Micro Hei (same recipe as 32px page titles). Latin stays
official `w500`/`w600`. Half-lead **3.2** / card **3.0** /
stroke **0.28** / plate **34** / far **10/24/-6 @ 10%** stay.
Not a Medium/Bold flip. Recapture after dart `3fd1a7cb2`:
`02=64c3192a` / scrolled `5502da00` / dark `14ae4b84`;
04 `30c34667` / 04-dark `64372546`. MAE vs `977c77570`
~0.56 / 0.52 / 0.44 on 02; ~0.67 / 0.54 on 04.
03/05 SAME. Restored 06 / 07 (MAE ≤ 0.09). **Not 精致.**

**2026-09-04 wake-0349 residual (after `8732d9c79`):**
Watch scored live Regular session/card goldens `02=64c3192a`.
STRUCTURE PASS. THEME OK. Type Regular stays — do **not** pile
3.2 / 3.0 / tracking. Search/+ circle weight: through-frost
**0.22 → 0.16**, search/plus drop near-pair halo (hits **40**,
plate **34**, `+` **40**). Schedule status plates **28 → 24**
(hit 38). Far **10/24/-6 @ 10%**. Recapture MAE vs `8732d9c79`
~0.017 / 0.017 / 0.002 on 02; ~0.011 / 0.073 on 04 — below
tester noise; goldens unrestored (`02=64c3192a` / scrolled
`5502da00` / dark `14ae4b84`; 04 `30c34667` / 04-dark
`64372546`). WidgetTester cannot prove the halo or 4px disc.
**Not 精致.**

**2026-09-04 wake-0405 residual (after dart `05ae9f93c`):**
Delayed duplicate of tip `7b8920736`. STRUCTURE PASS. THEME OK.
Do **not** pile frost 0.16 / search/+ discs / schedule 24 / dock
0.12 / Regular / 3.2 / 3.0 / 1.46. Press DONE. Official dark
`--oc-mobile-float-shadow` far is `0.34`; Flutter painted light
`0.10` on dark cards. Geometry stays **10/24/-6**. Light far stays
**10%**. Recapture after `05ae9f93c`: kept `02-projects-dark`
`53d62271` (MAE ~0.88) and `04-scheduled-dark` `ed188c0f`
(MAE ~0.53). Restored light 02/04 (MAE ~0.02) and 01/03/05/06/07/08.
**Not 精致.**

**2026-09-04 wake-0412 residual (after dart `be2eb9a63`):**
Watch scored live recapture tip `08f2d280b`. STRUCTURE PASS.
THEME OK. Do **not** pile Regular / 3.2 / 3.0 / 1.46 / frost 0.16 /
disc 24 / search plate 34. Dark card far stays **0.34**. Light far
stays **10/24/-6 @ 10%**. Press DONE. Official dark dock uses
`--oc-mobile-glass-shadow` near pair `0.30` / `0.28`; Flutter
painted none. No 8/20 umbra. Recapture after `be2eb9a63`: kept
`02-projects-dark` `8c63def9` (MAE ~1.07), `04-scheduled-dark`
`c3a7ae89` (MAE ~0.52), `05-settings-dark` `fa19b836` (MAE ~0.99).
Restored light 02/04 (MAE ~0.02) and 01/03/05/06/07/08.
**Not 精致.**

**2026-09-04 wake-0419 residual (after dart `18fa0439b`):**
Watch scored live dark-dock goldens `2f1d7a978`. STRUCTURE PASS.
THEME OK. Do **not** pile Regular / 3.2 / 3.0 / 1.46 / frost 0.16 /
disc 24 / search plate 34. Dark far **0.34** and dock near pair stay.
Press DONE. Assistant card names were raw `w600` Text. Port official
root `oc-mobile-entity-title` 16/20 plus HighlightedText CJK Regular.
Recapture after `18fa0439b`: kept `03-assistant` `1299800a` (MAE ~1.61).
02/04/05 dark SAME. Restored light 02/04 (MAE ~0.02) and 01/06/07/08.
**Not 精致.**

**2026-09-04 wake-0424 hunt (after `7d272b86f`):**
Watch scored live 03 Regular goldens `03=1299800a`. STRUCTURE PASS.
THEME OK. Do **not** pile Regular / 3.2 / 3.0 / 1.46 / frost 0.16 /
disc 24 / search plate 34. Dark far **0.34**, dock near pair, and
assistant Regular stay. Press DONE. Hunted official
`.oc-mobile-settings-search-field` `--oc-mobile-glass-shadow` (dark
`OcElevation.control` is empty). Recapture 05-dark stayed
BYTE-IDENTICAL (`fa19b836`, MAE 0) — WidgetTester clip / dark umbra
below noise. Dart reverted. No second recapture. Goldens stay
`7d272b86f` / `03=1299800a`.
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
| `07-chat.png` | Isolated pushed Chat (light): official 1.625 transcript leading, readable 40px `glassFill` 0.68 back / context-ring / more chips (`size-5`), centered title, official attach `size-5`, last-turn footer meta (copy / fork / tok/s / duration / clock), one “已处理”, folded file marks + `+N/-M`. More opens the session overflow sheet. Not UIKit glass. |
| `07-chat-dark.png` | Same isolated Chat with `ThemeMode.dark`. |
| `07-chat-activity.png` | Expanded 「已处理」 activity: gap under header, skill + terminal rows, foreground ink, OcGlyph folder/`>_`/chevron. |
| `08-permission.png` | Permission card only. |

**2026-09-04 wake-0548 residual (after dart `8346d0d04` / recapture):**
STRUCTURE PASS. THEME OK. Do **not** undo 20+10+20, session gap **2**,
title↔meta **4**, discs 34/28/24, search glyph **14**, frost through
**0.16**, far **10/24/-6**, schedule official float-shadow, press DONE.
Latin + live iOS titles use official CSS tracking (−0.012em /
−0.024em). Regular Micro Hei CJK on WidgetTester / Android keeps
1.46 / 1.02. Live iOS half-lead is the official CSS box. Android
frost saturate is official light 1.25 / dark 1.2 (not a UIKit clone).
Kept 02 `2df54af6` / scrolled `6bb51dd2` / dark `69a69b02`
(MAE ~2.48 / 2.64 / 2.04), 03 `255a25b8` (MAE ~0.25),
04 `13e78af7` / 04-dark `b2d7c84d` (MAE ~1.31 / 1.11).
Restored 05-dark saturate (MAE ~0.008) and 01/05/06/07/08.
**精致: 还没有.**

**2026-09-04 wake-0556 residual (dart `d468b87a3`):**
STRUCTURE PASS. THEME OK. Size-5 search/+ was below tester noise.
Wake-0601 re-locks glyph **14** (icons too large). Goldens unrestored.
**精致: 还没有.**

**2026-09-04 wake-0601 residual (after `1fd839771`):**
STRUCTURE PASS. THEME OK. Drop invented header OcFrosted — official
`.oc-mobile-collapsing-header` is transparent; fade `::after` only
on collapse. Search glyph **14**. Locked gaps/discs/frost/float-shadow
stay. Kept 02 `f4b67cc2` / dark `60d8ba3b` (MAE ~0.22 / 0.34),
03 `516861d0` (~0.23), 04 `07cd0f96` / 04-dark `2b06be36`
(~0.23 / 0.35), 05 `a24a0c47` (~0.23). Restored scrolled
(MAE ~0.06), 05-dark (~0.06), and 01/06/07/08.
Press DONE.
**精致: 还没有.**

**2026-09-04 wake-0602 residual (after dart `63b62e7f8`):**
STRUCTURE PASS. THEME OK. Port official `.oc-mobile-assistant-name`
15/20 / −0.02em — Flutter still invented root `oc-mobile-entity-title`
16/20 / −0.024em on `MobileAssistantCard`. Do not pile 3.2 / 1.46.
Locked 20+10+20, session gap **2**, title↔meta **4**, discs 34/28/24,
search glyph **14**, frost through **0.16**, official float-shadow,
Latin −0.012em/−0.024em stay. Press DONE.
Kept 03 `2bd63bf8` (MAE ~0.29). Restored scrolled / 05-dark / 06 / 07
(MAE ≤ 0.09). 02/04/05 light SAME.
**精致: 还没有.**

**2026-09-04 wake-0608 (stale `194528ca9` / dart `e3fcf1b89`):**
Watch scored the transparent-header recapture, not live
`eb042e3ad`. STRUCTURE PASS. THEME OK. VISUAL REJECT type/icon/
shadow vs README `mobile_projects` / `mobile_schedules` /
`mobile_chat` (MAE ~27). Header-frost MAE ~0.22 is below that
README gap because cream/orange + Regular Micro Hei + WidgetTester
frost are not official cool-gray PingFang + UIKit `UIGlassEffect`.
Do **not** rewind. Do **not** pile 3.2 / 3.0 / 1.46 / 1.02, do
**not** grow search glyph **14** or discs 34/28/24, do **not**
invent umbra or quieter-than-official far. Live tip already ports
official `.oc-mobile-assistant-name` 15/20 / −0.02em (`03=2bd63bf8`).
Locked float-shadow / Latin tracking stay. Press DONE. No second
recapture — pixels already include that type delta.
**精致: 还没有.**

**2026-09-04 wake-0615 residual (after dart `22a033b87`):**
STRUCTURE PASS. THEME OK. Official `MobileAssistantCard` still
invented shell entity-meta 12/15 and a 14px letter coin. Port root
`--oc-mobile-entity-meta` **13/16** plus official `AgentAvatar`
5×5 identicon (id seed, 38 inside the 1px muted ring, clipped to
the official circle). Do not pile 3.2 / 1.46 or grow search glyph
**14**. Press DONE. Kept 03 `3a881f07` (MAE ~0.61). 02/04/05/07
restored. Locked shadows stay.
**精致: 还没有.**

**2026-09-04 wake-0618 (stale `fedb7ae0c` / parent `eb042e3ad`):**
Quiet duplicate of wake-0611 goldens (`03=2bd63bf8`). Live tip is
`7599aff50` with official AgentAvatar + root entity-meta 13/16
(`03=3a881f07`). Do **not** rewind assistant-name 15/20. Do **not**
invent frost/umbra or unlock discs 34/28/24 / glyph **14**. README
MAE ~27 is cream/PingFang/UIKit glass. Press DONE. No second
recapture — live pixels already include the unread 03 delta.
**精致: 还没有.**

**2026-09-04 wake-0620 (stale dart `f9bcc8eed`, 0 PNG):**
Watch scored the AgentAvatar dart before recapture, so tip-tree
goldens still looked like wake-0611 `03=2bd63bf8`. Recapture
already landed on `7599aff50`: kept 03 `3a881f07` (MAE ~0.61).
02/04/05/07 SAME. Header stays official transparent
`MobileTabPageHeader`. Do not rewind. Press DONE.
**精致: 还没有.**

**2026-09-04 wake-0621 (delayed dup of `f9bcc8eed` / wake-0620):**
Same stale 03 `2bd63bf8`. Live goldens already match the
AgentAvatar dart (`3a881f07`). No second recapture. No banner
frost. Press DONE.
**精致: 还没有.**

**2026-09-04 wake-0622 (live `7599aff50` / dart `d48bdbed0`):**
STRUCTURE PASS. THEME OK. Mode tag still collapsed official
entity-meta 16 via `ocCssInk` (pill ~17 vs name 20). Port
`OcCssLine` 13/16 + pad 2 so the contact-card tag is 20.
Recapture MAE ~0.024 vs `03=3a881f07` — RESTORED (same class
as wake-0556 size-5). Goldens stay `7599aff50`. Do **not**
recapture again for this dart. Do not invent frost/umbra or
unlock discs 34/28/24 / glyph **14**. Press DONE. Honest
leftover is live PingFang + UIKit `UIGlassEffect`.
**精致: 还没有.**

**2026-09-04 wake-0627 (delayed dup of `d48bdbed0` / wake-0622):**
Watch scored the mode-tag dart before the unrestored
recapture note. Tip-tree goldens already BYTE-IDENTICAL to
wake-0622 (`03=3a881f07`). No second recapture. Header stays
official transparent `MobileTabPageHeader`. Press DONE.
**精致: 还没有.**

**2026-09-04 wake-0634 (identical `7599aff50` pixels):**
STRUCTURE PASS. THEME OK. Yee bars (type tight / icons large /
search/+ umbra / dock glass-shadow) score unread goldens.
Official knobs already locked: session `gap-0.5` **2**, title↔meta
**4**, Latin −0.012em/−0.024em, CJK 1.46/1.02 only, search glyph
**14** (size-5 was tester-invisible), discs 34/28/24, search
through **0.16** / no 8/20 (that coined the plate), dock
glass-shadow near-pair only (8/20 was a cream stadium), far
**10/24/-6 @ 10%**. Do **not** rewind. Do **not** invent gap /
tracking / umbra / frost clones. Press DONE. No recapture.
Honest leftover is live PingFang + UIKit `UIGlassEffect`.
**精致: 还没有.**

**2026-09-04 live PingFang / UIKit residual (blocked, no Mac pool):**
STRUCTURE PASS. THEME OK. VISUAL still REJECT on WidgetTester
goldens — that is expected. Live path is already wired:
`ocLiveIosType` keeps official Medium/Semibold for PingFang SC
(`Platform.isIOS`); iOS dock is `IosTabBarHost` →
`OpenChamberTabBarView` `UITabBar` + `UIGlassEffect` (iOS 26);
composer is `IosComposerHost` runtime `UIGlassEffect`. Android /
WidgetTester stay Regular CJK + clipped `BackdropFilter` (honest
degrade, not a Flutter glass clone). This Linux VM has no Xcode,
no iOS Simulator, and no connected self-hosted Mac worker.
`serve-sim` needs macOS. Do **not** invent gap / tracking /
size-5 / umbra / Noto-weight knobs to fake 精致 here. No
recapture — pixels stay `7599aff50`. Press DONE.
**精致: 还没有.** (needs a real iPhone or Mac Simulator)

**2026-09-05 secondary nav back + menu (`914c38a82` dart + recapture):**
Yee: 正文页面的返回键还有设置那些呢. Official
`MobileDetailNavigation` is `mobileGlass` + `arrow-left-s` size-5
on a 40 chip, centered title, trailing context ring + `more-2`.
Flutter `PushedNavBar` now paints the same frost (`glassFill` 0.68
/ blur 20 / foreground ink) for chat and Settings editors.
`chat-more` opens a real session overflow sheet (rename / pin /
sync / archive / delete — stub handlers). `chat-context` is the
official 18px ring (35% visual stub). Do **not** unlock catalog
search 14 / discs 34/28/24 / gap-0.5 **2** / 20+10+20.
KEEP: 07 `73a50267` / 07-dark `5ca4bf18` / 06 `aee7c288` /
06-dark `fa817da0` / 08 `35ff7fcb`. RESTORE noise: 02-scrolled /
03 / 05-dark / 07-activity (MAE ≤ 0.0003). **Not 精致** until
device glass is proven.

**2026-09-05 wake-0851 (no dart, no recapture):**
STRUCTURE PASS. THEME OK cream/orange. Secondary nav KEEP
goldens stay `07=73a50267` / `06=aee7c288` / `08=35ff7fcb`.
Catalog 01/02/scrolled/dark/03/04/05 still BYTE-IDENTICAL
wake-0622 (`7599aff50` pixels). Yee residual bars (type air /
icon weight / shadows / dock pill) vs README `mobile_*.png`
(MAE ~25–27) map to **already-locked official knobs**: session
`gap-0.5` **2**, title↔meta **4**, search glyph **14**, discs
**34/28/24**, search through **0.16** / no 8/20, dock
glass-shadow near-pair only, far **10/24/-6 @ 10%**,
`PushedNavBar` official `glassFill` 0.68 / size-5 / 40.
Unlocking any of those reopens the inflate / cream-coin /
cream-stadium loops. Honest leftover is live PingFang +
UIKit `UIGlassEffect` (blocked here: no Mac pool). Press
DONE. Do not invent gap / tracking / umbra / size-5 on
catalog. **精致: 还没有.**

**2026-09-05 wake-0855 STOP (Mac / iPhone pool):**
STRUCTURE PASS. THEME OK. Secondary `PushedNavBar` stays official
`MobileDetailNavigation` (`glassFill` 0.68 / size-5 / 40 / wired
overflow + 18px context ring). Catalog md5s stay wake-0622.
Residual 精致 (type air / icon scale / shadows / liquid dock)
is **live PingFang SC + UIKit `UIGlassEffect`** — already wired
(`ocLiveIosType`, `IosTabBarHost` / `OpenChamberTabBarView`,
`IosComposerHost`). This Linux VM has no Xcode, no iOS
Simulator run, no connected self-hosted Mac worker. `serve-sim`
needs macOS. macos-15 CI only *compiles* `Runner.app`.
**Do not fake glass in Flutter. Do not invent tester knobs.**
No dart. No recapture. Goldens unchanged. Next proof needs a
real iPhone or Mac Simulator pool. **精致: 还没有.**

**2026-09-05 P0 icon stroke (Yee: setting页的对比 / 图标都看不到):**
`settingsGlyphStrokeVisual` **0.12 → 1.25** (decoupled from dock
hairline; official settings Icon 1.5). Chevron **1.0**. Dock
`dockGlyphStrokeVisual` / folder-sparkles **0.12 → 1.25**
(official medium 2, bloom-safe; box 23 / fillBodies false /
wash 0.55 stay). Session more + schedule ellipsis inherit dock
1.25. File/footer marks own **1.0**. Search 14 / discs 34/28/24
/ gap-0.5 **2** / 20+10+20 / secondary-nav 0.68 stay. Recapture
05 + dock-bearing catalog / chat if strokes move. **Not 精致.**

KEEP after recapture (`5ebf0c287` dart + `b994a908e` goldens): 02 `f1c46938` / scrolled
`5bf88964` / dark `74925e59`; 03 `e844e196`; 04 `ae59df67` /
04-dark `53122746`; 05 `2b09a2ba` / 05-dark `701c6619`; 07
`984f327e` / 07-dark `7b7044ea` / activity `93cc5df8`; 08
`59860899`. Unchanged: 01 `3d8161fe`, 06 `aee7c288` / 06-dark
`fa817da0`. Icons visible again on 05 (row + dock). **Not 精致.**
