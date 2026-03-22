import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/logging/app_logger.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  String _filter = 'all'; // 'all', 'error', 'http', 'state'

  List<LogEntry> get _filteredEntries {
    final entries = AppLogger.instance.entries.reversed.toList();
    if (_filter == 'all') return entries;
    if (_filter == 'error') {
      return entries
          .where(
            (e) =>
                e.level == LogLevel.error || e.level == LogLevel.warning,
          )
          .toList();
    }
    return entries.where((e) => e.category == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export logs',
            onPressed: () async {
              final path = await AppLogger.instance.exportToFile();
              await Share.shareXFiles([XFile(path)], text: 'AGRO App Logs');
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to clipboard',
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: AppLogger.instance.exportAsJson()),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear logs',
            onPressed: () {
              AppLogger.instance.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AgroSpacing.sm),
            child: Row(
              children: [
                _chip('All', 'all'),
                _chip('Errors', 'error'),
                _chip('HTTP', 'http'),
                _chip('State', 'state'),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No log entries'))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (_, i) => _LogTile(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final active = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: AgroSpacing.xs),
      child: FilterChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    Color levelColor;
    switch (entry.level) {
      case LogLevel.error:
        levelColor = AgroColors.critical.text;
      case LogLevel.warning:
        levelColor = AgroColors.warning.text;
      case LogLevel.info:
        levelColor = AgroColors.info.text;
      default:
        levelColor = AgroColors.textSecondary;
    }

    final t = entry.timestamp;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

    return ListTile(
      dense: true,
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: levelColor, shape: BoxShape.circle),
      ),
      title: Text(
        entry.message,
        style: AgroTypography.body.copyWith(fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$time · ${entry.category}',
        style: AgroTypography.caption,
      ),
      onTap: entry.data != null
          ? () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(
                    entry.message,
                    style: AgroTypography.cardTitle,
                  ),
                  content: SingleChildScrollView(
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ')
                          .convert(entry.toJson()),
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              )
          : null,
    );
  }
}
