import 'package:flutter/material.dart';

import '../theme/agro_colors.dart';

/// Centralized SnackBar utility for consistent UI feedback.
///
/// Usage:
/// ```dart
/// AgroSnackBar.success(context, 'Item saved');
/// AgroSnackBar.error(context, 'Failed to save');
/// ```
///
/// Rules:
/// - NEVER use ScaffoldMessenger.of(context).showSnackBar() directly
/// - Always use AgroSnackBar.success() or AgroSnackBar.error()
abstract class AgroSnackBar {
  AgroSnackBar._();

  /// Show a success snackbar with green accent.
  static void success(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AgroColors.success.text,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show an error snackbar with critical red accent.
  static void error(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AgroColors.critical.text,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
