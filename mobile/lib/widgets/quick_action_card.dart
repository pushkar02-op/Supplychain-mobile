import 'package:flutter/material.dart';

import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';

class QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const QuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AgroColors.surface,
      elevation: 1,
      borderRadius: AgroShapes.cardRadius,
      child: InkWell(
        borderRadius: AgroShapes.cardRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AgroSpacing.md,
            horizontal: AgroSpacing.sm,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: AgroSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AgroTypography.captionEmphasis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
