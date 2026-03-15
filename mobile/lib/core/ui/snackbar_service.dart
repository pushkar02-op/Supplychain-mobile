import 'package:flutter/material.dart';

import '../../ui/widgets/agro_snack_bar.dart';

class SnackbarService {
  const SnackbarService._();

  static DateTime? _lastErrorShownAt;
  static String? _lastErrorMessage;

  static void showSuccess(BuildContext context, String message) {
    AgroSnackBar.success(context, message);
  }

  static void showError(BuildContext context, String message) {
    final now = DateTime.now();
    if (_lastErrorShownAt != null &&
        _lastErrorMessage == message &&
        now.difference(_lastErrorShownAt!) < const Duration(seconds: 1)) {
      return;
    }

    _lastErrorShownAt = now;
    _lastErrorMessage = message;
    AgroSnackBar.error(context, message);
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
