import 'json_parsers.dart';

/// Minimal DTO mirroring backend AuditLogRead schema.
class AuditLogEntry {
  final int id;
  final String action;
  final int actorUserId;
  final String entityType;
  final int? entityId;
  final int? warehouseId;
  final Map<String, dynamic>? eventMetadata;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.actorUserId,
    required this.entityType,
    this.entityId,
    this.warehouseId,
    this.eventMetadata,
    required this.createdAt,
  });

  String get actionType => action;
  Map<String, dynamic>? get metadata => eventMetadata;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final metadata = json['event_metadata'] ?? json['changes'];
    return AuditLogEntry(
      id: JsonParsers.parseInt(json['id']),
      actorUserId: JsonParsers.parseInt(
        json['user_id'] ?? json['actor_user_id'],
      ),
      action: JsonParsers.parseString(json['action_type'] ?? json['action']),
      entityType: JsonParsers.parseString(
        json['table_name'] ?? json['entity_type'],
      ),
      entityId:
          json['record_id'] != null || json['entity_id'] != null
              ? JsonParsers.parseInt(json['record_id'] ?? json['entity_id'])
              : null,
      warehouseId:
          json['warehouse_id'] == null
              ? null
              : JsonParsers.parseInt(json['warehouse_id']),
      eventMetadata:
          metadata is Map ? Map<String, dynamic>.from(metadata) : null,
      createdAt:
          JsonParsers.parseDate(json['created_at']) ?? DateTime(1970),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'actor_user_id': actorUserId,
    'action_type': action,
    'entity_type': entityType,
    'entity_id': entityId,
    'warehouse_id': warehouseId,
    'event_metadata': eventMetadata,
    'created_at': createdAt.toIso8601String(),
  };
}
