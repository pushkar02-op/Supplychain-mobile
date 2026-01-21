import 'package:flutter/material.dart';

import '../services/forecasting_service.dart';
import '../widgets/item_forecast_section.dart';

/// Item Detail Screen showing full item information including forecasting.
///
/// This screen is READ-ONLY with respect to forecasting data.
/// All forecasting values come directly from backend, no calculations here.
class ItemDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  List<ItemForecast> forecasts = [];
  bool isForecastLoading = true;
  String? forecastError;

  @override
  void initState() {
    super.initState();
    _fetchForecasts();
  }

  Future<void> _fetchForecasts() async {
    try {
      final fetchedForecasts =
          await ForecastingService.fetchForecastingSummary();
      if (!mounted) return;
      setState(() {
        forecasts = fetchedForecasts;
        isForecastLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        forecastError = e.toString();
        isForecastLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final aliases = List<Map<String, dynamic>>.from(item['aliases'] ?? []);
    final conversions = List<Map<String, dynamic>>.from(
      item['conversions'] ?? [],
    );
    final itemId = item['id'] as int;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(item['name'] ?? 'Item Detail'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Info Card
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.straighten,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Default UOM: ${item['default_uom_code'] ?? 'N/A'}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    if (item['item_code'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.tag, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Code: ${item['item_code']}',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Aliases Section
            if (aliases.isNotEmpty)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aliases',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children:
                            aliases
                                .map(
                                  (a) => Chip(
                                    label: Text(
                                      '${a['alias_name']} (${a['alias_code']})',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                ),
              ),

            // Conversions Section
            if (conversions.isNotEmpty)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Conversions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...conversions.map((c) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text('1 ${item['default_uom_code'] ?? ''} = '),
                              Text(
                                '${c['conversion_factor']} ${c['target_unit']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

            // Forecasting Section (Phase 9 - READ-ONLY)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ItemForecastSection(
                forecast: ForecastingService.getItemForecast(forecasts, itemId),
                isLoading: isForecastLoading,
                error: forecastError,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
