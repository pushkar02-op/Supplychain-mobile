import 'package:flutter/material.dart';

import '../theme/agro_colors.dart';
import '../theme/agro_shapes.dart';
import '../theme/agro_spacing.dart';

/// AGRO Card — Standard container widget
///
/// Replaces ad-hoc Card/Container usage with consistent styling.
///
/// Usage:
/// ```dart
/// AgroCard(child: Text('Content'))
/// AgroCard.outlined(child: Text('Outlined'))
/// AgroCard.subtle(child: Text('Subtle'))
/// ```

/// Card variant for visual distinction.
enum AgroCardVariant {
  /// Default card — elevated white surface.
  standard,

  /// Outlined card — no elevation, visible border.
  outlined,

  /// Subtle card — very low emphasis, grey background.
  subtle,
}

/// A standardized card container using the AGRO design system.
class AgroCard extends StatelessWidget {
  /// The content of the card.
  final Widget child;

  /// The card variant (standard, outlined, subtle).
  final AgroCardVariant variant;

  /// Optional padding override. Defaults to [AgroSpacing.cardPadding].
  final EdgeInsetsGeometry? padding;

  /// Optional margin around the card.
  final EdgeInsetsGeometry? margin;

  /// Optional border color override (for outlined variant or custom borders).
  final Color? borderColor;

  /// Optional callback when the card is tapped.
  final VoidCallback? onTap;

  const AgroCard({
    super.key,
    required this.child,
    this.variant = AgroCardVariant.standard,
    this.padding,
    this.margin,
    this.borderColor,
    this.onTap,
  });

  /// Creates an outlined card with a visible border.
  const AgroCard.outlined({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderColor,
    this.onTap,
  }) : variant = AgroCardVariant.outlined;

  /// Creates a subtle card with low emphasis styling.
  const AgroCard.subtle({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderColor,
    this.onTap,
  }) : variant = AgroCardVariant.subtle;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? EdgeInsets.all(AgroSpacing.cardPadding);

    // Determine styling based on variant
    Color backgroundColor;
    double elevation;
    BorderSide? side;

    switch (variant) {
      case AgroCardVariant.standard:
        backgroundColor = AgroColors.surface;
        elevation = 0;
        side = BorderSide(color: borderColor ?? AgroColors.dividerLight);
        break;
      case AgroCardVariant.outlined:
        backgroundColor = AgroColors.surface;
        elevation = 0;
        side = BorderSide(color: borderColor ?? AgroColors.divider);
        break;
      case AgroCardVariant.subtle:
        backgroundColor = AgroColors.surfaceVariant;
        elevation = 0;
        side = null;
        break;
    }

    final cardShape = RoundedRectangleBorder(
      borderRadius: AgroShapes.cardRadius,
      side: side ?? BorderSide.none,
    );

    Widget cardContent = Padding(padding: effectivePadding, child: child);

    if (onTap != null) {
      cardContent = InkWell(
        onTap: onTap,
        borderRadius: AgroShapes.cardRadius,
        child: cardContent,
      );
    }

    return Card(
      margin: margin ?? EdgeInsets.zero,
      elevation: elevation,
      color: backgroundColor,
      shape: cardShape,
      clipBehavior: Clip.antiAlias,
      child: cardContent,
    );
  }
}
