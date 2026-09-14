# SomaCare design system

One palette, one type scale, one set of components - for the student side and
the doctor side alike. The student dashboard set the direction; the doctor side
now renders from the same widgets rather than its own look-alikes.

Everything lives in two files:

| File | What it holds |
|---|---|
| `lib/theme/app_theme.dart` | Colour, type, spacing, radius, motion, touch tokens, and the single `ThemeData` |
| `lib/widgets/app_ui.dart` | The components screens compose from |

---

## The rules

1. **No screen declares a `Color(0x…)`.** Every colour has a semantic name in
   `AppColors`. If a screen needs a colour that is not there, add a token - don't inline a hex.
2. **No text below 11px.** `AppTypography.labelSmall` is the floor. Body copy is
   `bodyLarge` (15px).
3. **Every tappable thing is at least 48×48.** `AppTouch.minTarget`. The theme
   already enforces it for buttons; custom hit areas must too.
4. **Every icon-only control has a tooltip and a semantic label.**
5. **Colour is never the only signal.** Status chips carry a dot or an icon as
   well as a hue.
6. **A list has three states, not one:** loading (a skeleton, not a spinner),
   empty (explaining what would appear here and offering the action that
   creates it), and error (distinct from empty, with a retry).

---

## Colour

### Brand and status

| Token | Value | Used for |
|---|---|---|
| `primary` | `#2563EB` | The one blue: headers, primary actions, active nav |
| `success` | `#0D9488` | Confirmed, active, completed |
| `warning` | `#F59E0B` | Pending, expiring, needs attention |
| `error` | `#DC2626` | Urgent, emergency, destructive |
| `accent` | `#7C3AED` | AI, wellness, chat |

Each has a `…Wash` (10%) for icon chips and selected rows, a `…Tint` (16%) for
borders, and a `…Dark` for text on a light tint.

Before this consolidation the app carried four blues (`#3A86FF`, `#5B8CFF`,
`#2563EB`, `#3B82F6`) and five greens (`#22C55E`, `#2ECC71`, `#059669`,
`#16A34A`, `#0D9488`), which is why the two halves never looked related.

### Surfaces and text

| Token | Value | Contrast on `surface` |
|---|---|---|
| `pageBg` | `#F8FAFC` | - |
| `surface` | `#FFFFFF` | - |
| `surfaceMuted` | `#F1F5F9` | - |
| `border` | `#E2E8F0` | - |
| `textPrimary` | `#1E293B` | 13.2:1 - AAA |
| `textSecondary` | `#64748B` | 4.8:1 - AA |
| `textMuted` | `#94A3B8` | 2.6:1 - **decorative only**, never body text |

### Two special sets

- **`fill*`** - solid tile fills that carry white text at ≥4.5:1. White on
  `warning` is only 2.1:1, so the quick-action grid uses `fillAmber`
  (`#B45309`) instead. Same for `fillTeal`.
- **`*OnDark`** - the status hues lightened for the inverse surface (snack bars,
  tooltips), where the light-background versions fall under 3:1.

---

## Type

Fraunces for display and headings, Inter for UI, IBM Plex Mono for data
(dosages, prices, times).

| Role | Size | Face |
|---|---|---|
| `displayLarge` … `displaySmall` | 28 / 24 / 20 | Fraunces |
| `headlineLarge` … `headlineSmall` | 20 / 18 / 16 | Fraunces |
| `titleLarge` … `titleSmall` | 16 / 15 / 13.5 | Inter 600 |
| `bodyLarge` … `bodySmall` | 15 / 13.5 / 12.5 | Inter 400 |
| `labelLarge` … `labelSmall` | 14 / 12.5 / 11 | Inter 600 |

The previous scale ran 26px down to **8.5px** - smaller than a phone can render
legibly. `main.dart` also clamps the OS text scale to 0.85–1.4, so a user at
200% font size gets larger text without bursting fixed-height cards.

---

## Components

| Widget | What it is |
|---|---|
| `AppScreen` | Page chrome: sliver scroll view, pull-to-refresh, nav clearance |
| `AppPageHeader` | Eyebrow + display title + circular actions - the dashboard header |
| `AppDetailHeader` | Same, with a back affordance |
| `AppCircleButton` | 42px circle on a 48px target, tooltip required, optional badge |
| `AppCard` | White, 16px radius, hairline border. The only card |
| `AppIconChip` | Tinted square holding an icon |
| `AppSectionTitle` | Heading, optional count pill and "See all" |
| `AppStatCard` / `AppStatRow` | Metric tiles that wrap instead of overflowing |
| `AppHeroBanner` | Gradient call-to-action (emergency, AI check, urgent queue) |
| `AppQuickActionCard` / `AppQuickActionGrid` | The solid-colour action grid |
| `AppStatusChip` | Status pill; `.fromStatus()` maps a database string |
| `AppListRow` | Leading avatar/chip, title, subtitle, meta, trailing status |
| `AppAvatar` | Initials, falling back to an icon |
| `AppEmptyState` / `AppErrorState` | The two "nothing here" states |
| `AppSkeleton` / `AppSkeletonRow` | Loading placeholders; respect "reduce motion" |
| `AppBottomNav` | One nav bar; the shells differ only in `accent` |
| `showAppSnack` / `showAppConfirm` | Feedback in the app's voice |

### Role accents

The only sanctioned difference between the two sides:

```dart
AppColors.studentAccent  // = primary, blue
AppColors.doctorAccent   // = success, teal
```

Used for the active bottom-nav item. Everything else - page background, cards,
type, spacing, status colours, empty states - is shared.

---

## Adding a screen

```dart
AppScreen(
  onRefresh: _load,
  slivers: [
    SliverToBoxAdapter(
      child: AppPageHeader(eyebrow: 'Records', title: 'Lab results'),
    ),
    appSection(AppSectionTitle(title: 'Recent', count: results.length),
        bottom: AppSpacing.md),
    if (_loading)
      SliverList.separated(/* AppSkeletonRow */)
    else if (results.isEmpty)
      appSection(AppEmptyState(/* … */))
    else
      SliverPadding(/* AppListRow per result */),
  ],
)
```

`appSection(child)` wraps a box widget as a sliver with the standard 16px
gutter.
