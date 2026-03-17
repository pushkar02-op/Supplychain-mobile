class DriftResolutionRequest {
  final int batchId;
  final String resolutionType;
  final String? notes;

  const DriftResolutionRequest({
    required this.batchId,
    required this.resolutionType,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'batch_id': batchId,
        'resolution_type': resolutionType,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      };
}
