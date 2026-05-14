# ADR-0013: Design Tokens and Inter Font

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

There is no external design reference for KopiyanteaPOS. The visual language is being built from scratch (master prompt §4). Without a token system in place from day one, ad-hoc colors and hardcoded magic numbers will spread across feature widgets and become an untestable mess. The app also needs to:

- Render on a wide range of cashier devices, often outdoors and in fluorescent-lit shops.
- Stay **fully offline** — no Google Fonts CDN, no remote asset loading.
- Be color-blind safe — a busy cashier must distinguish "completed" from "voided" at a glance even under deuteranopia / protanopia.
- Use Indonesian-first typography (Latin extended for diacritics in names and addresses).

## Decision

Encode the design system as a small set of immutable, single-purpose modules under `/lib/core/theme/`, plus bundled Inter as the single typeface.

### Palette (master prompt §6.1)

- **Primary — Teal-700 `#0F766E`.** Distinct from the coffee-brown POS cliché. Color-blind safe.
- **Accent — Orange-600 `#EA580C`.** CTAs, discount badges.
- **Semantic:** Info Blue-600, Success **Sky-600** (not green — distinguishable from danger under common color-blindness), Warning Amber-600, Danger Red-600. Every semantic color is paired with an icon — color is never the sole signal.
- **Neutrals — Stone scale** (warm gray, hospitality feel). Light + dark mode each get full surface, alt-surface, border, three text levels, and a disabled token.

### Typography (master prompt §6.2)

Inter, four weights (400/500/600/700), bundled as Flutter assets under `/assets/fonts/`. A ten-step scale from `labelXs` (11pt) to `displayLg` (36pt). Line heights are part of each token (1.1–1.6 depending on size class), not computed at call sites.

### Spacing & radius (master prompt §6.3–6.4)

4pt base scale: `xs 4 / sm 8 / md 12 / lg 16 / xl 24 / xxl 32 / xxxl 48 / xxxxl 64`. Radius: `sm 4 / md 8 / lg 12 / xl 16 / full 999`.

### Touch targets (master prompt §6.5)

44 minimum, 48 standard, 56 primary tablet POS, 64 numeric keypad. Enforced by lint and by primitives (`AppButton`, `AppNumericKeypad`).

### Font bundling

Inter is shipped as an asset, never loaded from a CDN. Inter OFL license permits this. Four weights total ≈ 600 KB; acceptable APK bump (Section 14 risk #11). Subsetting to Latin + Indonesian glyphs is an option if APK size becomes critical.

### Module layout

```
/lib/core/theme/
  colors.dart       // abstract final class AppColors
  typography.dart   // abstract final class AppTypography
  spacing.dart      // abstract final class AppSpacing
  radius.dart       // abstract final class AppRadius
  app_theme.dart    // composes ThemeData for light + dark
```

All tokens are `abstract final class` + `static const` — no instances, no late init.

### Component primitives

Reusable widgets in `/lib/core/widgets/` consume tokens directly: `AppButton` (primary/secondary/danger/ghost), `AppTextField`, `AppCard`, `AppBadge`, `AppBottomSheet`, `AppEmptyState`, `AppLoadingIndicator`, `AppNumericKeypad`. Feature code never imports raw `Color` or `TextStyle` — only tokens or primitives.

## Consequences

**Positive:**
- One place to change colors, type scale, or spacing. Visual consistency falls out for free.
- Offline-first respected at the font level — first paint never blocks on network.
- Color-blind safety baked into the palette rather than discovered in QA.
- Dark mode is a swap of one `ThemeData`, not a per-screen rewrite.

**Negative:**
- ~600 KB APK growth from the font. Acceptable; mitigation available via subsetting.
- Discipline required: a developer slapping a raw `Color(0xff…)` into a widget breaks the system. Mitigation: lint rule + code review.
- Tokens locked early; if business pivots to a non-teal brand, a palette change is one file but a visual review across screens.

## Alternatives Considered

- **`google_fonts` package (CDN-loaded Inter).** Rejected outright: violates offline-first.
- **System fonts (San Francisco / Roboto).** Cheap, but inconsistent across Android OEMs and iOS — visual identity drifts per device.
- **Material 3 dynamic color.** Considered; rejected because chain branding must be fixed across devices, not derived from a user wallpaper.
- **Larger semantic palette (e.g., separate hover/focus/pressed colors for every component).** Rejected as premature; current tokens (`primaryLight`, `primaryDark`, surfaces) cover present needs and can extend later.
- **Tailwind-style numeric scale instead of named tokens.** Rejected: named tokens (`xl`, `displayLg`) read better in Flutter widget trees than `space-6` / `text-2xl` would.
