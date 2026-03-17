import 'package:flutter/material.dart';

import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';

class DashboardMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const DashboardMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AgroCard.outlined(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AgroShapes.cardRadius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AgroShapes.cardRadius,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: AgroSpacing.sm),
                Text(
                  value,
                  style: AgroTypography.metricValue.copyWith(color: color),
                ),
                const SizedBox(height: AgroSpacing.xs),
                Text(title, style: AgroTypography.metricLabel),
                const SizedBox(height: AgroSpacing.xs),
                const Divider(color: AgroColors.divider),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
