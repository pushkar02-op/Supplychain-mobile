import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/navigation/route_refresh_registry.dart';
import 'core/dio_client.dart';
import 'core/session/session_controller.dart';
import 'routes/app_router.dart';

void main() {
  debugPrint('[BOOT] main() started');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[BOOT] WidgetsFlutterBinding initialized');

  if (kIsWeb) {
    debugPrint('[BOOT] Forcing SemanticsBinding');
    SemanticsBinding.instance.ensureSemantics();
  }

  registerRouteRefreshRules();

  debugPrint('[BOOT] Running runApp');
  runApp(const ProviderScope(child: MyApp()));
  debugPrint('[BOOT] runApp called');
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _bootstrapped = false;

  Future<bool> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Do you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
    );
    return confirmed ?? false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) {
      return;
    }
    _bootstrapped = true;

    final isWidgetTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    if (!isWidgetTest) {
      DioClient.setup(
        refreshHandler:
            () => ref.read(sessionProvider.notifier).refreshAccessToken(),
        logoutHandler: () => ref.read(sessionProvider.notifier).logout(),
      );
    }

    Future.microtask(() {
      ref.read(sessionProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        return WillPopScope(
          onWillPop: () => _confirmExit(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
      title: 'Fruit Vendor Tool',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
    );
  }
}
