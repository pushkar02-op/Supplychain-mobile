import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/auth_provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '', password = '';
  bool isLoading = false;
  String errorMessage = '';

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
        debugPrint('[LOGIN_SCREEN] Calling AuthService.login...');
        final result = await AuthService.login(email, password);
        debugPrint('[LOGIN_SCREEN] AuthService.login result: $result');

        if (!mounted) {
            debugPrint('[LOGIN_SCREEN] Widget unmounted after login call.');
            return;
        }

        if (result == true) {
          debugPrint('[LOGIN_SCREEN] Login SUCCESS. Triggering AuthNotifier...');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Login successful')));
          
          await ref.read(authProvider.notifier).login();
          debugPrint('[LOGIN_SCREEN] AuthNotifier.login() returned.');
          return;
        } else {
          debugPrint('[LOGIN_SCREEN] Login FAILED. Result: $result');
          setState(() => errorMessage = result.toString());
        }
    } catch (e, st) {
        debugPrint('[LOGIN_SCREEN] Exception during login: $e');
        debugPrint(st.toString());
        setState(() => errorMessage = 'An error occurred: $e');
    }

    if (mounted) {
       setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // App Branding
              Icon(
                Icons.agriculture,
                size: 64,
                color: Colors.green[600],
              ),
              const SizedBox(height: 16),
              const Text(
                'AGRO Supply Chain',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vendor Management Portal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 48),
              // Form Fields
              Semantics(
                label: 'login-email',
                textField: true,
                enabled: true,
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (val) => email = val.trim(),
                  validator:
                      (val) => val!.isEmpty ? 'Please enter your email' : null,
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                label: 'login-password',
                textField: true,
                enabled: true,
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  obscureText: true,
                  onChanged: (val) => password = val.trim(),
                  validator:
                      (val) => val!.isEmpty ? 'Please enter your password' : null,
                ),
              ),
              const SizedBox(height: 24),
              if (errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              Semantics(
                label: 'login-submit',
                button: true,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isLoading ? null : _login,
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
