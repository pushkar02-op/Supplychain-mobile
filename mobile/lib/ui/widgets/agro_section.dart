import 'package:flutter/material.dart';

import '../theme/agro_spacing.dart';
import '../theme/agro_typography.dart';

/// AGRO Section — Consistent section header + content wrapper
///
/// Provides standardized section headers across all screens.
///
/// Usage:
/// ```dart
/// AgroSection(
///   title: 'Daily Operations',
///   child: Column(children: [...]),
/// )
/// ```

/// A section with a consistent header and content wrapper.
class AgroSection extends StatelessWidget {
  /// The section title (required).
  final String title;

  /// Optional subtitle below the title.
  final String? subtitle;

  /// Optional trailing widget (e.g., action button, badge).
  final Widget? trailing;

  /// The section content.
  final Widget child;

  /// Padding around the entire section.
  final EdgeInsetsGeometry? padding;

  /// Gap between header and content.
  final double? headerContentGap;

  const AgroSection({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding,
    this.headerContentGap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGap = headerContentGap ?? AgroSpacing.sectionHeaderGap;

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AgroTypography.sectionTitle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AgroTypography.caption),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: effectiveGap),
          // Content
          child,
        ],
      ),
    );
  }
}
