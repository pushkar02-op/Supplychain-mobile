import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class AppNavigation {
  const AppNavigation._();

  static void goOverview(BuildContext context) {
    context.go('/overview');
  }

  static void goOrders(BuildContext context) {
    context.go('/orders');
  }

  static void goStock(BuildContext context) {
    context.go('/stock');
  }

  static void goDispatch(BuildContext context) {
    context.go('/dispatch');
  }

  static void goMore(BuildContext context) {
    context.go('/more');
  }

  static Future<T?> createOrder<T>(BuildContext context) {
    return context.push<T>('/order-entry');
  }

  static Future<T?> receiveStock<T>(BuildContext context) {
    return context.push<T>('/stock-entry');
  }

  static Future<T?> createDispatch<T>(
    BuildContext context, {
    Object? extra,
  }) {
    return context.push<T>('/dispatch-entry', extra: extra);
  }
}
