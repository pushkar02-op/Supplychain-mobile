import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/screens/stock_entry_screen.dart';
import '/core/dio_client.dart'; // Ensure correct import

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
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: () {
              // Navigate to the stock entry screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StockEntryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: const Center(child: Text('Welcome to Fruit Vendor Tool!')),
    );
  }
}
