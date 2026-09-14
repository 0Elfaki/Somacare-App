import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SomaCare shared UI kit
/// ─────────────────────────────────────────────────────────────────────────────
///
/// These are the building blocks the student dashboard established, lifted out
/// so the doctor side renders from exactly the same widgets rather than its own
/// look-alikes. If a screen needs a header, a stat card, a hero banner, a
/// section title, a list row, or an empty state, it comes from here.
///
/// Every interactive element in this file presents at least
/// [AppTouch.minTarget] of hit area and carries a semantic label.

// ─── Page scaffolding ────────────────────────────────────────────────────────

/// The standard page chrome: off-white background, a scroll view that always
/// accepts an overscroll drag (so pull-to-refresh works even when the content
/// is short), and bottom padding that clears the nav bar.
///
/// Use [slivers] for a screen composed of sections. Pull-to-refresh is wired up
/// whenever [onRefresh] is supplied.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.slivers,
    this.onRefresh,
    this.backgroundColor,
    this.floatingActionButton,
    this.bottomBar,
    this.accent = AppColors.primary,
  });

  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        ...slivers,
        // Clears the bottom nav / home indicator so the last card is reachable.
        SliverToBoxAdapter(
          child: SizedBox(
            height:
                AppSpacing.bottomNavClearance +
                MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.pageBg,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
      body: onRefresh == null
          ? scroll
          : RefreshIndicator(
              onRefresh: onRefresh!,
              color: accent,
              backgroundColor: AppColors.surface,
              child: scroll,
            ),
    );
  }
}

/// Horizontal gutter used by every section.
class AppGutter extends StatelessWidget {
  const AppGutter({
    super.key,
    required this.child,
    this.top = 0,
    this.bottom = AppSpacing.lg,
  });

  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      top,
      AppSpacing.gutter,
      bottom,
    ),
    child: child,
  );
}

/// Convenience: wrap any box widget as a sliver with the standard gutter.
SliverToBoxAdapter appSection(
  Widget child, {
  double top = 0,
  double bottom = AppSpacing.lg,
}) => SliverToBoxAdapter(
  child: AppGutter(top: top, bottom: bottom, child: child),
);

// ─── Header ──────────────────────────────────────────────────────────────────

/// The greeting header used at the top of a dashboard: a small eyebrow line,
/// a display-face title, and up to two circular actions on the right.
///
/// This is the exact header the student dashboard uses; the doctor dashboard
/// now uses it too, which is most of why the two sides finally look alike.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
    this.leading,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.pageBg,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        MediaQuery.paddingOf(context).top + AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null)
                  Text(
                    eyebrow!,
                    style: BloomTextStyles.inter(
                      size: AppTypography.bodySmall,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (eyebrow != null) const SizedBox(height: 2),
                Text(
                  title,
                  style: BloomTextStyles.fraunces(
                    size: AppTypography.displaySmall,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: BloomTextStyles.inter(
                      size: AppTypography.bodyMedium,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: AppSpacing.sm), a],
        ],
      ),
    );
  }
}

/// A back-navigation header for detail screens - same visual language as
/// [AppPageHeader] but with a leading back affordance instead of a greeting.
class AppDetailHeader extends StatelessWidget {
  const AppDetailHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      title: title,
      subtitle: subtitle,
      actions: actions,
      leading: AppCircleButton(
        icon: Icons.arrow_back_rounded,
        tooltip: 'Back',
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

/// A 44px circular button on a 48px hit target, with a required tooltip so it
/// is never an unlabelled icon.
class AppCircleButton extends StatelessWidget {
  const AppCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
    this.foreground = AppColors.textPrimary,
    this.background = AppColors.surface,
    this.borderColor = AppColors.border,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badgeCount;
  final Color foreground;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      button: true,
      label: badgeCount > 0 ? '$tooltip, $badgeCount unread' : tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppTouch.minTarget,
            height: AppTouch.minTarget,
            child: Center(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, size: 20, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );

    if (badgeCount <= 0) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          right: 2,
          top: 2,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.rectangle,
                borderRadius: AppRadius.fullAll,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: BloomTextStyles.inter(
                  size: AppTypography.labelSmall,
                  weight: FontWeight.w700,
                  color: AppColors.onPrimary,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Surfaces ────────────────────────────────────────────────────────────────

/// The one card. White, 16px radius, hairline border, no drop shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.semanticLabel,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final String? semanticLabel;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: borderColor),
        boxShadow: elevated ? AppShadows.card : AppShadows.none,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardAll,
        child: onTap == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                borderRadius: AppRadius.cardAll,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );

    if (semanticLabel == null) return decorated;
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: decorated,
    );
  }
}

/// A small tinted square holding an icon - the motif used on stat cards,
/// list rows and quick actions.
class AppIconChip extends StatelessWidget {
  const AppIconChip({
    super.key,
    required this.icon,
    required this.color,
    this.size = 42,
    this.radius = AppRadius.md,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(icon, color: color, size: size * 0.48),
  );
}

// ─── Section furniture ───────────────────────────────────────────────────────

/// A section heading, optionally with a trailing "See all" action.
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.count,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: BloomTextStyles.fraunces(
                    size: AppTypography.headlineSmall,
                    weight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Text(
                    '$count',
                    style: BloomTextStyles.inter(
                      size: AppTypography.labelSmall,
                      weight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(0, AppTouch.minTarget),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

// ─── Stats ───────────────────────────────────────────────────────────────────

/// A compact metric card: tinted icon chip, big value, two-line label.
class AppStatCard extends StatelessWidget {
  const AppStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final shown = loading ? '-' : value;
    // Icon badge on top, value + label stacked underneath - the same
    // silhouette as an [AppQuickActionCard] tile, just on a white surface
    // with a soft shadow instead of a saturated fill. Keeping the two card
    // families visually related is the point: a stat card and a quick
    // action now read as the same kind of object at a glance.
    return AppCard(
      onTap: onTap,
      elevated: true,
      borderColor: AppColors.borderSubtle,
      padding: const EdgeInsets.all(AppSpacing.lg),
      semanticLabel: '$shown ${label.replaceAll('\n', ' ')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconChip(icon: icon, color: color, size: 40, radius: AppRadius.md),
          const SizedBox(height: AppSpacing.md),
          Text(
            shown,
            style: BloomTextStyles.fraunces(
              size: AppTypography.headlineMedium,
              weight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: BloomTextStyles.inter(
              size: AppTypography.labelMedium,
              color: AppColors.textSecondary,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A row of stat cards that never overflows: it wraps to a second line on
/// narrow screens rather than squeezing.
class AppStatRow extends StatelessWidget {
  const AppStatRow({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The card stacks icon → value → label vertically now, so it needs
        // far less width than the old icon-beside-text row did. ~108px is
        // enough for a short value and a two-line label without clipping.
        final perRow = constraints.maxWidth >= cards.length * 108
            ? cards.length
            : 2;
        const gap = AppSpacing.md;
        final width =
            (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

// ─── Hero banner ─────────────────────────────────────────────────────────────

/// The full-bleed gradient call-to-action used for emergency care, the AI
/// symptom checker, and (on the doctor side) the next patient in the queue.
class AppHeroBanner extends StatelessWidget {
  const AppHeroBanner({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$eyebrow. $title',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.cardAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    eyebrow,
                    style: BloomTextStyles.eyebrow(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: BloomTextStyles.fraunces(
                size: AppTypography.headlineMedium,
                weight: FontWeight.w600,
                color: Colors.white,
                height: 1.25,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: BloomTextStyles.inter(
                size: AppTypography.bodyMedium,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: gradient.first,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(AppTouch.minTarget),
                    ),
                    child: Text(primaryLabel),
                  ),
                ),
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        minimumSize: const Size.fromHeight(AppTouch.minTarget),
                      ),
                      child: Text(
                        secondaryLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick actions ───────────────────────────────────────────────────────────

class AppQuickAction {
  const AppQuickAction({
    required this.label,
    required this.category,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String category;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// A tile in the quick-actions grid: a saturated fill with a translucent icon
/// chip and white text - the look the student dashboard established.
///
/// Pass one of the `AppColors.fill*` values as [AppQuickAction.color]; the
/// lighter status hues do not carry white text at an accessible contrast.
class AppQuickActionCard extends StatelessWidget {
  const AppQuickActionCard({super.key, required this.action});

  final AppQuickAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${action.label}, ${action.category}',
      excludeSemantics: true,
      child: Material(
        color: action.color,
        borderRadius: AppRadius.cardAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.onTap,
          splashColor: Colors.white.withValues(alpha: 0.16),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Icon(action.icon, color: Colors.white, size: 19),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BloomTextStyles.inter(
                        size: AppTypography.titleSmall,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BloomTextStyles.inter(
                        size: AppTypography.labelSmall,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A two-column grid of quick actions, sized so the tallest tile fits without
/// overflowing at large text scales.
class AppQuickActionGrid extends StatelessWidget {
  const AppQuickActionGrid({super.key, required this.actions});

  final List<AppQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    // Grow the tile as the user's text scale grows, so the label never clips.
    final double scale = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(1.0, 1.6).toDouble();
    return GridView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        mainAxisExtent: 116 * scale,
      ),
      itemBuilder: (context, i) => AppQuickActionCard(action: actions[i]),
    );
  }
}

// ─── Status ──────────────────────────────────────────────────────────────────

enum AppStatusTone { neutral, info, success, warning, danger, accent }

extension AppStatusToneColors on AppStatusTone {
  Color get foreground => switch (this) {
    AppStatusTone.neutral => AppColors.textSecondary,
    AppStatusTone.info => AppColors.primary,
    AppStatusTone.success => AppColors.successDark,
    AppStatusTone.warning => AppColors.warningDark,
    AppStatusTone.danger => AppColors.error,
    AppStatusTone.accent => AppColors.accent,
  };

  Color get background => switch (this) {
    AppStatusTone.neutral => AppColors.surfaceMuted,
    AppStatusTone.info => AppColors.primaryWash,
    AppStatusTone.success => AppColors.successWash,
    AppStatusTone.warning => AppColors.warningWash,
    AppStatusTone.danger => AppColors.errorWash,
    AppStatusTone.accent => AppColors.accentWash,
  };
}

/// Maps the status strings the database uses onto a tone, so every screen
/// colours "confirmed" or "cancelled" identically.
AppStatusTone appStatusTone(String? status) => switch (status?.toLowerCase()) {
  'confirmed' || 'active' || 'completed' || 'approved' || 'paid' =>
    AppStatusTone.success,
  'pending' || 'awaiting' || 'scheduled' || 'in_review' => AppStatusTone.warning,
  'cancelled' || 'canceled' || 'denied' || 'rejected' || 'expired' ||
  'failed' => AppStatusTone.danger,
  'emergency' || 'urgent' => AppStatusTone.danger,
  'in_progress' || 'ongoing' => AppStatusTone.info,
  _ => AppStatusTone.neutral,
};

/// A status pill. Carries a dot as well as colour, so meaning does not rest on
/// hue alone.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.dense = false,
  });

  /// Builds a chip straight from a database status string.
  factory AppStatusChip.fromStatus(String? status, {bool dense = false}) {
    final text = (status == null || status.isEmpty) ? 'unknown' : status;
    final pretty = text
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
        )
        .join(' ');
    return AppStatusChip(
      label: pretty,
      tone: appStatusTone(status),
      dense: dense,
    );
  }

  final String label;
  final AppStatusTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? AppSpacing.sm : AppSpacing.md,
          vertical: dense ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: AppRadius.fullAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 13, color: tone.foreground)
            else
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: tone.foreground,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: BloomTextStyles.inter(
                size: AppTypography.labelSmall,
                weight: FontWeight.w700,
                color: tone.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── List rows ───────────────────────────────────────────────────────────────

/// The standard row inside a list card: leading chip or avatar, title,
/// subtitle, optional trailing status and chevron.
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.meta,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final String? meta;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: BloomTextStyles.inter(
                    size: AppTypography.titleSmall,
                    weight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: BloomTextStyles.inter(
                      size: AppTypography.bodyMedium,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (meta != null && meta!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta!,
                    style: BloomTextStyles.mono(
                      size: AppTypography.labelSmall,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
          if (showChevron && onTap != null) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}

/// A circular initials avatar. Falls back to a person icon when there is no
/// name to derive initials from.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 42,
    this.color = AppColors.primary,
    this.imageUrl,
  });

  final String? name;
  final double size;
  final Color color;

  /// A `profiles.avatar_url` value. When set (student or doctor has
  /// uploaded a profile photo), it's shown instead of the initials circle;
  /// a load failure falls back to initials rather than a broken image.
  final String? imageUrl;

  String get _initials {
    final n = name?.trim() ?? '';
    if (n.isEmpty) return '';
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _fallback() {
    final initials = _initials;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, size: size * 0.5, color: color)
          : Text(
              initials,
              style: BloomTextStyles.inter(
                size: size * 0.36,
                weight: FontWeight.w700,
                color: color,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return _fallback();
    return ClipOval(
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _fallback(),
      ),
    );
  }
}

// ─── Empty, loading and error states ─────────────────────────────────────────

/// What a list shows when it has nothing in it. Always explains what would
/// appear here, and offers the action that would create the first item.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = AppStatusTone.info,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppStatusTone tone;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: tone.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: tone.foreground),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: BloomTextStyles.fraunces(
              size: AppTypography.headlineSmall,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: BloomTextStyles.inter(
              size: AppTypography.bodyMedium,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, AppTouch.minTarget),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// What a screen shows when a load failed. Distinguishing this from "empty"
/// matters: one is a normal state, the other needs a retry.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.wifi_off_rounded,
    title: title,
    message: message,
    tone: AppStatusTone.danger,
    actionLabel: onRetry == null ? null : 'Try again',
    onAction: onRetry,
  );
}

/// A neutral skeleton block used while content loads. Prefer this over a bare
/// spinner: it keeps the page from jumping when data arrives.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = AppRadius.sm,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    // Respect the OS "reduce motion" setting: a shimmer that never stops is a
    // vestibular trigger for some users.
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.surfaceMuted,
              AppColors.border,
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// A placeholder card shaped like the list rows it stands in for.
class AppSkeletonRow extends StatelessWidget {
  const AppSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) => const AppCard(
    padding: EdgeInsets.all(AppSpacing.md),
    child: Row(
      children: [
        AppSkeleton(height: 42, width: 42, radius: AppRadius.md),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(height: 13, width: 140),
              SizedBox(height: AppSpacing.sm),
              AppSkeleton(height: 11, width: 90),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Bottom navigation ───────────────────────────────────────────────────────

class AppNavDestination {
  const AppNavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;
}

/// One bottom navigation bar, used by both shells. The only difference between
/// the student and doctor variants is [accent].
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.destinations,
    this.accent = AppColors.primary,
  });

  final int currentIndex;
  final List<AppNavDestination> destinations;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.navBar,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    accent: accent,
                    position: i + 1,
                    total: destinations.length,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.accent,
    required this.position,
    required this.total,
  });

  final AppNavDestination destination;
  final bool selected;
  final Color accent;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: '${destination.label}, tab $position of $total',
      excludeSemantics: true,
      child: InkWell(
        onTap: destination.onTap,
        // A visible ripple, so a tap is acknowledged even before the route
        // changes.
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.06),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: AppRadius.fullAll,
              ),
              child: Icon(
                selected ? destination.activeIcon : destination.icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BloomTextStyles.inter(
                size: AppTypography.labelSmall,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Feedback helpers ────────────────────────────────────────────────────────

/// Shows a snack bar in the app's voice. Use [tone] rather than passing raw
/// colours, so success and failure look the same everywhere.
void showAppSnack(
  BuildContext context,
  String message, {
  AppStatusTone tone = AppStatusTone.neutral,
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final icon = switch (tone) {
    AppStatusTone.success => Icons.check_circle_rounded,
    AppStatusTone.danger => Icons.error_rounded,
    AppStatusTone.warning => Icons.warning_rounded,
    _ => Icons.info_rounded,
  };
  final iconColor = switch (tone) {
    AppStatusTone.success => AppColors.successOnDark,
    AppStatusTone.danger => AppColors.errorOnDark,
    AppStatusTone.warning => AppColors.warningOnDark,
    _ => AppColors.infoOnDark,
  };

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
          ],
        ),
        action: action,
        duration: const Duration(seconds: 4),
      ),
    );
}

/// A confirmation dialog with a destructive default styling when [destructive]
/// is set. Returns true only if the user explicitly confirms.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
          ),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? AppColors.error : AppColors.primary,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Converts raw database, network, or platform exceptions into human-friendly,
/// reassuring messages that explain what the user can do, rather than leaking
/// raw SQL/PostgreSQL/Postgrest errors or stack traces to the UI.
String userFriendlyErrorMessage(
  dynamic error, {
  String defaultMessage = 'Something went wrong. Please try again.',
}) {
  if (error == null) return defaultMessage;
  final errStr = error.toString().toLowerCase();

  // PostgreSQL / Supabase RLS recursion (42P17) or policy violation
  if (errStr.contains('42p17') || errStr.contains('infinite recursion')) {
    return 'We had trouble verifying permissions. Please pull down to refresh or try again in a moment.';
  }
  if (errStr.contains('pgrst') ||
      errStr.contains('postgrest') ||
      errStr.contains('jwt')) {
    if (errStr.contains('jwt expired') ||
        errStr.contains('invalid claim') ||
        errStr.contains('not authenticated')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (errStr.contains('row-level security') ||
        errStr.contains('permission denied')) {
      return 'You do not have permission to perform this action.';
    }
  }
  // Network / connection errors
  if (errStr.contains('socketexception') ||
      errStr.contains('failed host lookup') ||
      errStr.contains('connection refused') ||
      errStr.contains('network is unreachable') ||
      errStr.contains('clientexception') ||
      errStr.contains('timeout')) {
    return 'Unable to connect to SomaCare servers. Please check your internet connection.';
  }
  // Data constraints
  if (errStr.contains('duplicate key') || errStr.contains('already exists')) {
    return 'This record already exists.';
  }
  if (errStr.contains('foreign key') || errStr.contains('violates foreign key')) {
    return 'Unable to complete this action because a required record was not found.';
  }

  // If the error message is already human-readable and clean
  if (error is String &&
      !error.contains('Exception') &&
      !error.contains('Error:') &&
      !error.contains('code:') &&
      error.length < 90) {
    return error;
  }

  return defaultMessage;
}

