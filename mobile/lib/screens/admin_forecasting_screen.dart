import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/forecasting_provider.dart';
import '../services/forecasting_service.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_status_badge.dart';

class AdminForecastingScreen extends ConsumerWidget {
  const AdminForecastingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(forecastingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Forecast Alerts')),
      body: forecastAsync.when(
        data: (forecasts) {
          if (forecasts.isEmpty) {
            return const AgroEmptyState(
              icon: Icons.analytics_outlined,
              title: 'No forecast alerts available.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AgroSpacing.screenPadding),
            itemCount: forecasts.length,
            separatorBuilder:
                (_, __) => const SizedBox(height: AgroSpacing.sm),
            itemBuilder: (context, index) {
              final forecast = forecasts[index];
              return _ForecastCard(forecast: forecast);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, stack) => AgroErrorState.loadFailed(
              onRetry: () => ref.read(forecastingProvider.notifier).refresh(),
            ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final ItemForecast forecast;

  const _ForecastCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final status = AgroStatusParser.fromForecastSignal(forecast.signal);
    final daysToZero = forecast.daysToZero;
    final daysLabel =
        daysToZero == null ? 'n/a' : daysToZero.toStringAsFixed(0);

    return AgroCard.outlined(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item #${forecast.itemId}',
                style: AgroTypography.cardTitle,
              ),
              AgroStatusBadge.compact(
                status: status,
                label: status.label,
              ),
            ],
          ),
          const SizedBox(height: AgroSpacing.xs),
          Text(
            'Days to zero: $daysLabel',
            style: AgroTypography.caption,
          ),
          const SizedBox(height: AgroSpacing.xs),
          Text(
            'Ledger qty: ${forecast.currentLedgerQty.toStringAsFixed(1)}',
            style: AgroTypography.caption,
          ),
          if (forecast.avgDailyOutflow != null) ...[
            const SizedBox(height: AgroSpacing.xs),
            Text(
              'Avg outflow: ${forecast.avgDailyOutflow!.toStringAsFixed(2)}',
              style: AgroTypography.caption,
            ),
          ],
          const Divider(color: AgroColors.divider),
        ],
      ),
    );
  }
}
