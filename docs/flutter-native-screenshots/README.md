# Flutter native screenshots (Yee visual review)

Real `apps/mobile_flutter` widgets, captured with `WidgetTester` + `RenderRepaintBoundary.toImage`.

- Device: **390×844** logical pixels, `devicePixelRatio` **3** (PNG 1170×2532)
- Locale: **zh-CN**
- Regenerator: `apps/mobile_flutter/test/flutter_native_screenshots_test.dart`
- Fonts: `test/review_fonts.dart` loads Roboto Regular+Medium. CJK Regular stays WenQuanYi Micro Hei; **Noto Sans CJK SC Medium** loads when `fonts-noto-cjk-extra` is present (SC face from the TTC) so official `font-medium` / `font-semibold` titles are a real Medium cut — not a miter stem, not Regular clamped to w400, not Noto Bold. Droid is last fallback. **Chrome icons are painted `OcGlyph` paths** — do not accept empty-square CupertinoIcons tofu.
- WidgetTester runs as Android. Header / dock use clipped `BackdropFilter` through-plates (iOS 26 live chrome is UIKit `UIGlassEffect`; these PNGs cannot prove that). Search uses `OcGlassChip` through-frost (`glassChipThrough` 0.22, σ14, official saturate, 36 plate — not a 0.34 cream coin, no 8/20 umbra, no 0.68 coin). Chat / schedule discs keep `glassChipFill` 0.34. Solid `+` is official 40 primary. Chat detail-nav chips are the official 40 `mobileIcon` hit. Project shells keep the official float-shadow trio — near pair (2 + 12) plus far 10/64/-16 as true black at official 10% (`rgb(0 0 0 / 0.1)`; softer blur/spread, not a darker umbra). Schedule cards use the same official 10% far with a quieter near pair. Nested worktree groups keep the official 1px inset border, painted a hair darker so the shell reads on cream. No Material 8/20 umbra. Schedule status hit is official 38; painted plate is 5; glyph is 2 at dock visual 0.12; plate is glassChipThrough + inset highlight (no OcGlassChip frost/chip shadow); schedule ellipsis is 10 at dock 0.12; scheduled-add is official ink (foreground disc). Project / schedule 14/18 titles use cardTitleHalfLead 2.7 (not session 4.7). Dock plate fill is 0 on WidgetTester (cream fill always reads as a stadium). Frost is `blur(20) saturate(1.25)` + glass-shadow near-pair (2/12) so selected `/55` is a through-mix on the list, not a cream pill. Official `floatSurface` 0.45 is too solid here. Chat detail-nav chips stay official 40 `mobileIcon` frost discs (not 44 coins, not flat glyphs). Dock selected is mix-only `interactive-selection/55` (no hairline pill, no RGB@0.55, no nested frost). Session rows stay in the official ~40 class with a 4.7px CJK half-lead plus Medium title↔subtitle air (40 + 4×4.7 + 24 → 82.8 — gap residual, not 7.5 half-lead / 70; ceiling ~4.75). Session titles paint `ocCssInk` inside the 16/12 box + pinned 4.7 half-lead as official `font-medium` fill (Noto/PingFang Medium, no miter stem, no shade); Latin stays ReviewSans Medium. Project / page titles use official `font-semibold`. Tracking 1.42 opens the 12px CJK band; project titles use 1.02. Stay under 1.5 / 1.1. Do not pile half-lead. No Medium CJK on review/CI. Project-shell frost (`floatSurface` 0.45) sits behind that ink so 12px cores are not composited through the plate. Project / schedule 14/18 titles paint `ocCssInk` in the official CSS box plus cardTitleHalfLead 2.7 so Regular CJK is not packed; session 4.7 stays on 12px rows only. Card title tracking is 0. Review-face titles (collapsing page title, project/schedule/dock/chat) paint Regular — w600 faux-bold blobs the DroidSansFallback cut. Dock labels paint Regular with 0 tracking so CJK stays open. Project leading / worktree / session-more / schedule-ellipsis / 「更多」chevron / search / settings nav paint dock visual stroke 0.12 so Flutter bloom is not a coin. Folder / sparkles / calendar / gear all paint 23px at visual stroke 0.12. Composer is official `--surface-subtle` with no elevation / no frost; idle+ready send is official solid foreground `SendCircleIcon` (arrow-up, idle 0.55). File-type marks are stroke-only silhouettes at visual 0.12, not blue squares. Footer action stroke is 0.12. These PNGs cannot prove live iOS glass or 精致. Real iOS still keeps live glass on UIKit overlays. Mid-scroll proof: `02-projects-scrolled.png`. This Linux VM cannot run an iOS Simulator. Goldens reserve `viewPadding.top = 47` for the status area; they do **not** paint a fake UIKit status bar.
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

| File | Screen |
|---|---|
| `01-connect.png` | QR primary, inset grouped fields (no floating-label overlap). |
| `02-projects.png` | Light: catalog sand/orange. Overlay collapsing header. Large title ↔ first card keeps the official expand-shift spacer + `gap-6` air (not a restPeek pull). One project shell: header + padded session/worktree groups. |
| `02-projects-scrolled.png` | Same Projects list jumped just past the official 48px collapse. Title is compact; cards stay visible under the translucent header (not an emptied mid-scroll). |
| `02-projects-dark.png` | Same Projects surface after Appearance → Dark (catalog `OcTokens`, not a photo recolor). |
| `03-assistant.png` | Contact cards (name / mode / summary). No 「启用助理」 toggle. |
| `04-scheduled.png` | Light: catalog tokens. Quiet schedule status discs. Soft float cards. Dock 计划 uses the official calendar grid (filled plate + date holes, not calendar-clock). |
| `04-scheduled-dark.png` | Same Scheduled surface after Appearance → Dark. |
| `05-settings.png` | Large title, pill search, inset groups. |
| `06-settings-appearance.png` | Light: language + theme. Latin labels must render. No `iosNativeUi`. |
| `06-settings-appearance-dark.png` | Appearance after tapping Dark — tokens switch live. |
| `07-chat.png` | Isolated pushed Chat (light): official 1.625 transcript leading, 40px glass chips, centered title, official attach `size-5`, last-turn footer meta (copy / fork / tok/s / duration / clock), one “已处理”, folded file marks + `+N/-M`. Not UIKit glass. |
| `07-chat-dark.png` | Same isolated Chat with `ThemeMode.dark`. |
| `07-chat-activity.png` | Expanded 「已处理」 activity: gap under header, skill + terminal rows, foreground ink, OcGlyph folder/`>_`/chevron. |
| `08-permission.png` | Permission card only. |
