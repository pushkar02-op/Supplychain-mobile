import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/forecasting_service.dart';

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

    if (forecast == null) {
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
          // Header with Signal Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Forecasting',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              _buildSignalBadge(forecast!.signal),
            ],
          ),
          const SizedBox(height: 12),

          // Metrics Grid
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
                  '${forecast!.currentLedgerQty.toStringAsFixed(1)} units',
                ),
                const Divider(height: 16),
                _buildMetricRow(
                  'Burn Rate (7d avg)',
                  forecast!.avgDailyOutflow != null
                      ? '${forecast!.avgDailyOutflow!.toStringAsFixed(2)} units/day'
                      : 'No recent outflow',
                ),
                const Divider(height: 16),
                _buildMetricRow(
                  'Days to Zero',
                  forecast!.daysToZero != null
                      ? '${forecast!.daysToZero!.toStringAsFixed(0)} days'
                      : 'N/A (no outflow)',
                ),
                const Divider(height: 16),
                _buildMetricRow(
                  'Est. Stockout Date',
                  forecast!.projectedStockoutDate ?? 'N/A',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Signal Explanation
          _buildSignalExplanation(forecast!.signal),

          const SizedBox(height: 12),

          // Disclaimer (UX Copy Truthfulness)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This forecast is based on recent dispatch activity. '
                    'It assumes recent demand continues. '
                    'Seasonality and future changes are not considered.',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ),

          // Last refreshed timestamp
          if (forecast!.lastRefreshed != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last refreshed: ${DateFormat('MMM d, h:mm a').format(forecast!.lastRefreshed!)}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
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

  Widget _buildSignalBadge(String signal) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (signal) {
      case 'CRITICAL':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        icon = Icons.error;
        break;
      case 'REORDER_SOON':
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        icon = Icons.warning;
        break;
      case 'WATCH':
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade800;
        icon = Icons.visibility;
        break;
      case 'STABLE':
      default:
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            signal.replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalExplanation(String signal) {
    String explanation;

    // Signal explanations map 1:1 to documented thresholds (Phase 9 architecture)
    switch (signal) {
      case 'CRITICAL':
        explanation =
            'Stock expected to run out in less than 3 days. Immediate attention needed.';
        break;
      case 'REORDER_SOON':
        explanation =
            'Stock expected to run out in less than 7 days. Plan reorder this week.';
        break;
      case 'WATCH':
        explanation =
            'Stock expected to run out in less than 14 days. Monitor closely.';
        break;
      case 'STABLE':
      default:
        explanation =
            'Stock levels are stable with no immediate action required.';
        break;
    }

    return Text(
      explanation,
      style: TextStyle(
        fontSize: 11,
        color: Colors.grey.shade700,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
