/// Minimal DTO mirroring backend AuditLogRead schema.
class AuditLogEntry {
  final int id;
  final int actorUserId;
  final String actionType;
  final String entityType;
  final int? entityId;
  final Map<String, dynamic>? eventMetadata;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.actorUserId,
    required this.actionType,
    required this.entityType,
    this.entityId,
    this.eventMetadata,
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as int,
      actorUserId:
          json['user_id'] as int? ?? json['actor_user_id'] as int? ?? 0,
      actionType: json['action_type'] as String? ?? '',
      entityType:
          json['table_name'] as String? ?? json['entity_type'] as String? ?? '',
      entityId: json['record_id'] as int? ?? json['entity_id'] as int?,
      eventMetadata:
          json['event_metadata'] as Map<String, dynamic>? ??
          json['changes'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
