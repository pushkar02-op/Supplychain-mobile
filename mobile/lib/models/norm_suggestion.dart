import 'json_parsers.dart';

/// A single normalization suggestion for a bill item.
///
/// Maps a billed item (e.g. "BH-Garlic, 500 gm × 2 Count")
/// to a stock quantity (e.g. "1.0 kg").
class NormSuggestionItem {
  final int billItemId;
  final String itemName;
  final String? itemCode;
  final double billedQty;
  final String billedUom;
  final TargetItemBrief? targetItem;
  final String ruleType;
  final double? ruleValue;
  final double? stockQty;
  final String? stockUom;
  final String source; // "confirmed_rule", "parser", "ambiguous"
  final int? existingRuleId;
  final bool needsConfirmation;

  NormSuggestionItem({
    required this.billItemId,
    required this.itemName,
    this.itemCode,
    required this.billedQty,
    required this.billedUom,
    this.targetItem,
    required this.ruleType,
    this.ruleValue,
    this.stockQty,
    this.stockUom,
    required this.source,
    this.existingRuleId,
    required this.needsConfirmation,
  });

  factory NormSuggestionItem.fromJson(Map<String, dynamic> json) {
    final suggestion = json['suggestion'] as Map<String, dynamic>? ?? {};
    return NormSuggestionItem(
      billItemId: JsonParsers.parseInt(json['bill_item_id']),
      itemName: JsonParsers.parseString(json['item_name']),
      itemCode: json['item_code']?.toString(),
      billedQty: JsonParsers.parseNum(json['billed_qty']),
      billedUom: JsonParsers.parseString(json['billed_uom']),
      targetItem: json['target_item'] != null
          ? TargetItemBrief.fromJson(
              json['target_item'] as Map<String, dynamic>)
          : null,
      ruleType: JsonParsers.parseString(suggestion['rule_type']),
      ruleValue: suggestion['rule_value'] != null
          ? JsonParsers.parseNum(suggestion['rule_value'])
          : null,
      stockQty: suggestion['stock_qty'] != null
          ? JsonParsers.parseNum(suggestion['stock_qty'])
          : null,
      stockUom: suggestion['stock_uom']?.toString(),
      source: JsonParsers.parseString(suggestion['source'], fallback: 'ambiguous'),
      existingRuleId: suggestion['existing_rule_id'] != null
          ? JsonParsers.parseInt(suggestion['existing_rule_id'])
          : null,
      needsConfirmation:
          JsonParsers.parseBool(suggestion['needs_confirmation']),
    );
  }

  /// Which UI category this item belongs to.
  NormCategory get category {
    if (source == 'confirmed_rule' && !needsConfirmation) {
      return NormCategory.auto;
    }
    if (ruleType == 'AMBIGUOUS_REVIEW') return NormCategory.manual;
    if (ruleType == 'RANGE_WEIGHT_REVIEW') return NormCategory.review;
    if (needsConfirmation) return NormCategory.confirm;
    return NormCategory.auto;
  }
}

class TargetItemBrief {
  final int id;
  final String name;
  final String stockUom;

  TargetItemBrief({
    required this.id,
    required this.name,
    required this.stockUom,
  });

  factory TargetItemBrief.fromJson(Map<String, dynamic> json) {
    return TargetItemBrief(
      id: JsonParsers.parseInt(json['id']),
      name: JsonParsers.parseString(json['name']),
      stockUom: JsonParsers.parseString(json['stock_uom']),
    );
  }
}

/// Response from the norm-suggestions endpoint.
class NormSuggestionsResponse {
  final int billId;
  final List<NormSuggestionItem> items;

  NormSuggestionsResponse({required this.billId, required this.items});

  factory NormSuggestionsResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return NormSuggestionsResponse(
      billId: JsonParsers.parseInt(json['bill_id']),
      items: rawItems
          .map((e) =>
              NormSuggestionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Response from the generate-stock endpoint.
class GenerateStockResponse {
  final int createdCount;
  final int skippedCount;
  final List<GenerateStockCreated> created;
  final List<GenerateStockSkipped> skipped;

  GenerateStockResponse({
    required this.createdCount,
    required this.skippedCount,
    required this.created,
    required this.skipped,
  });

  factory GenerateStockResponse.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['created'] as List<dynamic>? ?? [];
    final rawSkipped = json['skipped'] as List<dynamic>? ?? [];
    return GenerateStockResponse(
      createdCount: JsonParsers.parseInt(json['created_count']),
      skippedCount: JsonParsers.parseInt(json['skipped_count']),
      created: rawCreated
          .map((e) =>
              GenerateStockCreated.fromJson(e as Map<String, dynamic>))
          .toList(),
      skipped: rawSkipped
          .map((e) =>
              GenerateStockSkipped.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GenerateStockCreated {
  final int billItemId;
  final String itemName;
  final double stockQty;
  final String stockUom;
  final int stockEntryId;

  GenerateStockCreated({
    required this.billItemId,
    required this.itemName,
    required this.stockQty,
    required this.stockUom,
    required this.stockEntryId,
  });

  factory GenerateStockCreated.fromJson(Map<String, dynamic> json) {
    return GenerateStockCreated(
      billItemId: JsonParsers.parseInt(json['bill_item_id']),
      itemName: JsonParsers.parseString(json['item_name']),
      stockQty: JsonParsers.parseNum(json['stock_qty']),
      stockUom: JsonParsers.parseString(json['stock_uom']),
      stockEntryId: JsonParsers.parseInt(json['stock_entry_id']),
    );
  }
}

class GenerateStockSkipped {
  final int billItemId;
  final String itemName;
  final String reason;

  GenerateStockSkipped({
    required this.billItemId,
    required this.itemName,
    required this.reason,
  });

  factory GenerateStockSkipped.fromJson(Map<String, dynamic> json) {
    return GenerateStockSkipped(
      billItemId: JsonParsers.parseInt(json['bill_item_id']),
      itemName: JsonParsers.parseString(json['item_name']),
      reason: JsonParsers.parseString(json['reason']),
    );
  }
}

/// UI categorization for norm suggestions.
enum NormCategory {
  auto,    // Confirmed rule exists — green, no action needed
  confirm, // Clean suggestion, first time — blue, tap "Accept"
  review,  // Range weight estimate — orange, editable value
  manual,  // Ambiguous — red, user must type value
  skip,    // User chose to skip — grey
}
