import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:nexiva/presentation/providers/auth_provider.dart";

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool signup}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authControllerProvider);
      if (signup) {
        await auth.signUpWithEmail(_email.text.trim(), _password.text.trim());
      } else {
        await auth.signInWithEmail(_email.text.trim(), _password.text.trim());
      }
    } catch (e) {
      setState(() {
        _error = "Authentication failed. Please verify your credentials.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Nexiva", style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text("Routine intelligence for your day", style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 18),
                  TextField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Password"),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                  FilledButton(
                    onPressed: _loading ? null : () => _submit(signup: false),
                    child: _loading ? const CircularProgressIndicator() : const Text("Sign In"),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loading ? null : () => _submit(signup: true),
                    child: const Text("Create Account"),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () async {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });

                            try {
                              await ref.read(authControllerProvider).signInWithGoogle();
                            } catch (_) {
                              setState(() {
                                _error = "Google Sign-In failed. Check Firebase Auth provider setup.";
                              });
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _loading = false;
                                });
                              }
                            }
                          },
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text("Continue with Google"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
