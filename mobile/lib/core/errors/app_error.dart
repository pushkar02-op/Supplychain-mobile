class AppError implements Exception {
  final String detail;
  final String? ruleId;
  final Map<String, dynamic>? metadata;
  final int? statusCode;

  AppError({required this.detail, this.ruleId, this.metadata, this.statusCode});

  @override
  String toString() {
    return 'AppError: $detail${ruleId != null ? ' (Rule: $ruleId)' : ''}';
  }
}
