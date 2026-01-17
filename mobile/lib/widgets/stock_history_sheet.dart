import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/stock_history.dart';
import '../services/stock_service.dart';

class StockHistorySheet extends StatefulWidget {
  final int stockEntryId;
  final String itemName;
  final String currentQtyLabel; // e.g. "Current: 8.0 kg"

  const StockHistorySheet({
    super.key,
    required this.stockEntryId,
    required this.itemName,
    required this.currentQtyLabel,
  });

  static void show(
    BuildContext context, {
    required int stockEntryId,
    required String itemName,
    required String currentQtyLabel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => StockHistorySheet(
            stockEntryId: stockEntryId,
            itemName: itemName,
            currentQtyLabel: currentQtyLabel,
          ),
    );
  }

  @override
  State<StockHistorySheet> createState() => _StockHistorySheetState();
}

class _StockHistorySheetState extends State<StockHistorySheet> {
  late Future<StockHistoryResponse> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = StockService.getStockHistory(widget.stockEntryId);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.itemName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.currentQtyLabel,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: FutureBuilder<StockHistoryResponse>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading history: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final history = snapshot.data!;
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [_buildTimeline(history)],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeline(StockHistoryResponse history) {
    if (history.isVoided) {
      return Container(
        padding: const EdgeInsets.all(12),
        color: Colors.red.shade50,
        child: const Text(
          'This receipt has been voided.',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, yyyy h:mm a');
    final items = <Widget>[];

    // 1. Current State (Top of timeline logic roughly, but visually we want reverse chrono?)
    // Actually, "Timeline" usually implies oldest at bottom or top.
    // Let's do Reverse Chronologial (Newest Top).

    // Adjustments (Newest First)
    for (final adj in history.adjustments) {
      items.add(
        _buildTimelineItem(
          date: dateFormat.format(adj.createdAt),
          title: 'Stock Adjustment',
          subtitle: 'Reason: ${adj.reason}',
          trailing: Text(
            '${adj.quantityDelta > 0 ? "+" : ""}${adj.quantityDelta} ${adj.unit}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color:
                  adj.quantityDelta > 0
                      ? Colors.green[700]
                      : Colors.orange[800],
            ),
          ),
          icon: Icons.edit_note,
          color: Colors.orange.shade100,
          iconColor: Colors.orange.shade800,
        ),
      );
      items.add(const SizedBox(height: 16));
    }

    // Receipt (Original)
    items.add(
      _buildTimelineItem(
        date: dateFormat.format(history.receipt.receivedDate),
        title: 'Stock Received',
        subtitle:
            history.receipt.source != null
                ? 'Source: ${history.receipt.source}'
                : 'Initial Entry',
        trailing: Text(
          '+${history.receipt.quantity} ${history.receipt.unit}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        icon: Icons.inventory_2,
        color: Colors.green.shade50,
        iconColor: Colors.green.shade700,
        isLast: true,
      ),
    );

    return Column(children: items);
  }

  Widget _buildTimelineItem({
    required String date,
    required String title,
    required String subtitle,
    required Widget trailing,
    required IconData icon,
    required Color color,
    required Color iconColor,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time Column
        SizedBox(
          width: 0,
          // Actually, let's put date inside content for density on mobile
        ),
        // Icon & Line
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40, // Fixed height connector or flex?
                // Flex is hard in ListView children unless using IntrinsicHeight, which is expensive.
                // For now, fixed height connector or visual gap.
                // Let's use a CustomPainter if we want perfect line.
                // Or just a vertical divider.
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  trailing,
                ],
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[800], fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
