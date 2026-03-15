import 'package:flutter/material.dart';

import '../services/forecasting_service.dart';
import '../ui/semantics/agro_status.dart';
import '../ui/widgets/agro_decision_card.dart';

/// Widget that displays forecasting information for a single item.
/// This widget is READ-ONLY and displays data exactly as received from backend.
///
/// Per Phase 9 architecture:
/// - No calculations are performed in UI
/// - All data comes from GET /admin/forecasting/summary
/// - Signal thresholds are documented, not computed here
class ItemForecastSection extends StatelessWidget {
  final ItemForecast? forecast;
  final bool isLoading;
  final String? error;

  const ItemForecastSection({
    super.key,
    this.forecast,
    this.isLoading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final currentForecast = forecast;
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Forecasting',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Forecast data unavailable. This may happen if forecasts have not been refreshed recently.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (currentForecast == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Forecasting',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'No forecast available for this item. This item may not have recent dispatch activity.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decision Card (Replaces Header/Badge/Explanation logic)
          _buildDecisionCard(currentForecast),

          const SizedBox(height: 16),

          // Metrics Grid (PRESERVED)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildMetricRow(
                  'Current Quantity',
                  '${currentForecast.currentLedgerQty.toStringAsFixed(1)} units',
                ),
                const Divider(height: 16),
                _buildMetricRow(
                  'Burn Rate (7d avg)',
                  currentForecast.avgDailyOutflow != null
                      ? '${currentForecast.avgDailyOutflow!.toStringAsFixed(2)} units/day'
                      : 'No recent outflow',
                ),
                const Divider(height: 16),
                _buildMetricRow(
                  'Days to Zero',
                  currentForecast.daysToZero != null
                      ? '${currentForecast.daysToZero!.toStringAsFixed(0)} days'
                      : 'N/A (no outflow)',
                ),
                const Divider(height: 16),
                _buildMetricRow(
                  'Est. Stockout Date',
                  currentForecast.projectedStockoutDate
                          ?.toIso8601String()
                          .split('T')
                          .first ??
                      'N/A',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionCard(ItemForecast forecast) {
    // 1. Status Mapping
    final status = AgroStatusParser.fromForecastSignal(forecast.signal);

    // 2. Headeline Mapping (Strictly from documented rules)
    String primaryMessage;
    switch (forecast.signal) {
      case 'CRITICAL':
        primaryMessage = "Immediate stockout risk";
        break;
      case 'REORDER_SOON':
        primaryMessage = "Reorder required soon";
        break;
      case 'WATCH':
        primaryMessage = "Monitor stock closely";
        break;
      case 'STABLE':
      default:
        primaryMessage = "Stock levels are stable";
        break;
    }

    // 3. Secondary Message (Computed fields)
    String? secondaryMessage;
    if (forecast.daysToZero != null) {
      secondaryMessage =
          "Estimated stockout in ${forecast.daysToZero!.toStringAsFixed(0)} days";
    }

    // 4. Explanation (Verbatim disclaimer)
    const explanation =
        'This forecast is based on recent dispatch activity. '
        'It assumes recent demand continues. '
        'Seasonality and future changes are not considered.';

    return AgroDecisionCard(
      status: status,
      primaryMessage: primaryMessage,
      secondaryMessage: secondaryMessage,
      explanation: explanation,
      source: 'Forecasting',
      lastUpdated: forecast.lastRefreshed ?? DateTime.now(),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
