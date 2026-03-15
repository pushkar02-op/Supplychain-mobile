import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef RouteRefreshCallback = void Function(WidgetRef ref);

class RouteRefreshRegistry {
  RouteRefreshRegistry._();

  static final Map<String, RouteRefreshCallback> _callbacks = {};

  static void register(String routePrefix, RouteRefreshCallback callback) {
    _callbacks[routePrefix] = callback;
  }

  static void run(String location, WidgetRef ref) {
    for (final entry in _callbacks.entries) {
      if (location.startsWith(entry.key)) {
        entry.value(ref);
      }
    }
  }
}
