import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/core/dio_client.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Log the user out using DioClient's logout method
              await DioClient.logout();

              // Navigate to the login screen using GoRouter
              context.go(
                '/login',
              ); // Ensures we navigate properly with GoRouter
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () => context.push('/stock-list'),
              icon: const Icon(Icons.add_box),
              label: const Text('Stock List'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/orders'),
              icon: const Icon(Icons.assignment),
              label: const Text('Daily Orders'),
            ),
          ],
        ),
      ),
    );
  }
}
