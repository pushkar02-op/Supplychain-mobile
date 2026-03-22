import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String category; // "http", "state", "error", "ui", "lifecycle"
  final String message;
  final Map<String, dynamic>? data;
  final String? stackTrace;

  LogEntry({
    required this.level,
    required this.category,
    required this.message,
    this.data,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'category': category,
        'message': message,
        if (data != null) 'data': data,
        if (stackTrace != null) 'stack_trace': stackTrace,
      };
}

class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int _maxBufferSize = 500;
  final Queue<LogEntry> _buffer = Queue<LogEntry>();
  bool _initialized = false;

  /// Call once during app startup.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    info('lifecycle', 'Logger initialized');
  }

  void _add(LogEntry entry) {
    _buffer.addLast(entry);
    while (_buffer.length > _maxBufferSize) {
      _buffer.removeFirst();
    }
    if (kDebugMode) {
      debugPrint(
        '[${entry.level.name.toUpperCase()}][${entry.category}] ${entry.message}',
      );
    }
  }

  void debug(String category, String message, {Map<String, dynamic>? data}) {
    _add(
      LogEntry(
        level: LogLevel.debug,
        category: category,
        message: message,
        data: data,
      ),
    );
  }

  void info(String category, String message, {Map<String, dynamic>? data}) {
    _add(
      LogEntry(
        level: LogLevel.info,
        category: category,
        message: message,
        data: data,
      ),
    );
  }

  void warning(String category, String message, {Map<String, dynamic>? data}) {
    _add(
      LogEntry(
        level: LogLevel.warning,
        category: category,
        message: message,
        data: data,
      ),
    );
  }

  void error(
    String category,
    String message, {
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
  }) {
    _add(
      LogEntry(
        level: LogLevel.error,
        category: category,
        message: message,
        data: data,
        stackTrace: stackTrace?.toString(),
      ),
    );
  }

  /// Get all entries (oldest first).
  List<LogEntry> get entries => _buffer.toList();

  /// Get only error and warning entries.
  List<LogEntry> errors() =>
      _buffer
          .where(
            (e) =>
                e.level == LogLevel.error || e.level == LogLevel.warning,
          )
          .toList();

  /// Export buffer as pretty-printed JSON string.
  String exportAsJson() {
    final list = _buffer.map((e) => e.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  /// Write buffer to a file and return the file path.
  Future<String> exportToFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/agro_logs_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(exportAsJson());
    return file.path;
  }

  /// Clear the buffer.
  void clear() => _buffer.clear();
}
