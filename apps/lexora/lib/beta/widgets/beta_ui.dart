import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BetaSurface extends StatelessWidget {
  const BetaSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  bool get _isApple =>
      Platform.isMacOS ||
      Platform.isIOS ||
      debugDefaultTargetPlatformOverride == TargetPlatform.macOS ||
      debugDefaultTargetPlatformOverride == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(_isApple ? 16 : 22);
    final content = Material(
      color:
          color ??
          (_isApple ? scheme.surface.withValues(alpha: .72) : scheme.surface),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: _isApple ? .46 : .62),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
    if (!_isApple) return content;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: content,
      ),
    );
  }
}

class BetaMetric extends StatelessWidget {
  const BetaMetric({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) => BetaSurface(
    padding: const EdgeInsets.all(15),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: accent ?? Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class BetaSectionTitle extends StatelessWidget {
  const BetaSectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}
