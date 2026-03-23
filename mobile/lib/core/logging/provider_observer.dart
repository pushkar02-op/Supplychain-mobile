import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_logger.dart';

class AppProviderObserver extends ProviderObserver {
  final AppLogger _logger = AppLogger.instance;

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    _logger.debug(
      'state',
      'Provider created: ${provider.name ?? provider.runtimeType.toString()}',
    );
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    final name = provider.name ?? provider.runtimeType.toString();

    if (newValue is AsyncError) {
      _logger.error(
        'state',
        'Provider error: $name',
        data: {'provider': name, 'error': newValue.error.toString()},
        stackTrace: newValue.stackTrace,
      );
    } else if (previousValue is AsyncLoading && newValue is AsyncData) {
      _logger.debug('state', 'Provider loaded: $name');
    }
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    _logger.error(
      'state',
      'Provider failed: ${provider.name ?? provider.runtimeType.toString()}',
      data: {
        'provider': provider.name ?? provider.runtimeType.toString(),
        'error': error.toString(),
      },
      stackTrace: stackTrace,
    );
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    _logger.debug(
      'state',
      'Provider disposed: ${provider.name ?? provider.runtimeType.toString()}',
    );
  }
}
