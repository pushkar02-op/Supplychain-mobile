import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/dio_client.dart';
import 'routes/app_router.dart';

import 'package:mobile/providers/auth_provider.dart';

void main() {
  DioClient.setup();
  runApp(const ProviderScope(child: MyApp()));
}



class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Connect DioClient's 401 callback to Riverpod AuthNotifier
    DioClient.onUnauthorized = () {
      ref.read(authProvider.notifier).logout();
    };

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      title: 'Fruit Vendor Tool',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
    );
  }
}
