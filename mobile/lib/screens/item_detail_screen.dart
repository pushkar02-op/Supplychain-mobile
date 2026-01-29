import 'package:flutter/material.dart';

import '../services/forecasting_service.dart';
import '../services/item_service.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_card.dart';
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

  // Alias metrics (Read-Only, Observational)
  List<Map<String, dynamic>> aliasMetrics = [];

  @override
  void initState() {
    super.initState();
    _fetchForecasts();
    _fetchAliasMetrics();
  }

  Future<void> _fetchAliasMetrics() async {
    final metrics = await ItemService.fetchAliasMetrics();
    if (!mounted) return;
    setState(() => aliasMetrics = metrics);
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

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: Text(item['name'] ?? 'Item Detail'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AgroColors.dividerLight, height: 1.0),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AgroSpacing.screenPadding,
          vertical: AgroSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Lifecycle Panel (Status indicator)
            _buildLifecyclePanel(item),
            const SizedBox(height: AgroSpacing.sectionGap),

            _buildIdentitySection(item),
            const SizedBox(height: AgroSpacing.sectionGap),

            _buildAliasesSection(item),
            const SizedBox(height: AgroSpacing.sectionGap),

            _buildConversionsSection(item),
            const SizedBox(height: AgroSpacing.sectionGap),

            _buildForecastingSection(item),
            const SizedBox(height: AgroSpacing.xl),
          ],
        ),
      ),
    );
  }

  // 0️⃣ Lifecycle Panel (Status display)
  Widget _buildLifecyclePanel(Map<String, dynamic> item) {
    final status = item['status'] ?? 'ACTIVE';
    final isActive = status == 'ACTIVE';

    return AgroCard(
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isActive
                      ? AgroColors.success.background
                      : AgroColors.textSecondary,
            ),
          ),
          const SizedBox(width: AgroSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: AgroTypography.cardTitle.copyWith(
                    color:
                        isActive
                            ? AgroColors.success.text
                            : AgroColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? 'This item is available for all operations.'
                      : 'This item has been deactivated and is not available for new operations.',
                  style: AgroTypography.caption.copyWith(
                    color: AgroColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1️⃣ Identity Section (Top)
  Widget _buildIdentitySection(Map<String, dynamic> item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item['name'] ?? 'Unknown Item',
          style: AgroTypography.screenTitle.copyWith(fontSize: 24),
        ),
        if (item['item_code'] != null) ...[
          const SizedBox(height: AgroSpacing.xs),
          Text(
            'Code: ${item['item_code']}',
            style: AgroTypography.caption.copyWith(fontSize: 14),
          ),
        ],
        const SizedBox(height: AgroSpacing.md),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AgroColors.neutral.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AgroColors.neutral.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.straighten,
                    size: 14,
                    color: AgroColors.textSecondary,
                  ),
                  const SizedBox(width: AgroSpacing.iconTextGapCompact),
                  Text(
                    'Default UOM: ${item['default_uom_code'] ?? 'N/A'}',
                    style: AgroTypography.captionEmphasis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 2️⃣ Aliases Section — “Naming Memory”
  Widget _buildAliasesSection(Map<String, dynamic> item) {
    final aliases = List<Map<String, dynamic>>.from(item['aliases'] ?? []);

    if (aliases.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aliases', style: AgroTypography.sectionTitle),
        const SizedBox(height: AgroSpacing.sectionHeaderGap),
        AgroCard.outlined(
          padding: EdgeInsets.zero,
          child: Column(
            children:
                aliases.asMap().entries.map((entry) {
                  final index = entry.key;
                  final a = entry.value;
                  final isLast = index == aliases.length - 1;

                  // Find seen_count from aliasMetrics
                  final metric = aliasMetrics.firstWhere(
                    (m) => m['alias_id'] == a['id'],
                    orElse: () => {'seen_count': null},
                  );
                  final seenCount = metric['seen_count'];

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AgroSpacing.cardPadding),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a['alias_name'] ?? '',
                                    style: AgroTypography.body,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    a['alias_code'] ?? '',
                                    style: AgroTypography.tiny,
                                  ),
                                ],
                              ),
                            ),
                            if (seenCount != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AgroColors.background,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Seen $seenCount times',
                                  style: AgroTypography.caption,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          color: AgroColors.dividerLight,
                        ),
                    ],
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  // 3️⃣ Conversions Section — “Unit Memory”
  Widget _buildConversionsSection(Map<String, dynamic> item) {
    final conversions = List<Map<String, dynamic>>.from(
      item['conversions'] ?? [],
    );

    if (conversions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Conversions', style: AgroTypography.sectionTitle),
        const SizedBox(height: AgroSpacing.sectionHeaderGap),
        AgroCard(
          child: Column(
            children:
                conversions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final c = entry.value;
                  final isLast = index == conversions.length - 1;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Text(
                              '1 ${item['default_uom_code'] ?? ''}',
                              style: AgroTypography.bodySecondary,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Icon(
                                Icons.arrow_right_alt,
                                size: 16,
                                color: AgroColors.divider,
                              ),
                            ),
                            Text(
                              '${c['conversion_factor']} ${c['target_unit']}',
                              style: AgroTypography.emphasis,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          color: AgroColors.dividerLight,
                        ),
                    ],
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  // 4️⃣ Forecasting / Decision Section
  // Visually separated operational signal
  Widget _buildForecastingSection(Map<String, dynamic> item) {
    final itemId = item['id'] as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Operational Signal', style: AgroTypography.sectionTitle),
        const SizedBox(height: AgroSpacing.sectionHeaderGap),
        ItemForecastSection(
          forecast: ForecastingService.getItemForecast(forecasts, itemId),
          isLoading: isForecastLoading,
          error: forecastError,
        ),
      ],
    );
  }
}
