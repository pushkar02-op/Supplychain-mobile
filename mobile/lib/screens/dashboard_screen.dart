import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/auth_provider.dart';
import '/core/dio_client.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Log the user out using AuthProvider
              // The router will automatically redirect to /login
              await ref.read(authProvider.notifier).logout();
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
              label: const Text('Stock Entry'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/orders'),
              icon: const Icon(Icons.assignment),
              label: const Text('Daily Orders'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/dispatch-entries'),
              icon: const Icon(Icons.assignment),
              label: const Text('Dispatch Entries'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/invoices'),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Invoices'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/rejection-list'),
              icon: const Icon(Icons.delete),
              label: const Text('Rejection List'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/inventory'),
              icon: const Icon(Icons.inventory),
              label: const Text('Inventory'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/items'),
              icon: const Icon(Icons.inventory),
              label: const Text('Item list'),
            ),
          ],
        ),
      ),
    );
  }
}
