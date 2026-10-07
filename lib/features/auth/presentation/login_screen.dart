import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/brand.dart';
import '../../../core/messages.dart';
import '../domain/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final notifier = ref.read(authNotifierProvider.notifier);

    if (_isSignUp) {
      await notifier.signUpWithEmail(email, password);
    } else {
      await notifier.signInWithEmail(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authStatus = ref.watch(authNotifierProvider);

    final t = context.t;
    final isLoading = authStatus is AuthLoading;
    final errorMessage = authStatus is AuthError ? authStatus.message : null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: const PleasanceFooter(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const Center(child: FahrbarTile(size: 76)),
                const SizedBox(height: 14),
                Text(
                  'fahrbar',
                  style: display(54, color: ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp ? t.createAccount : t.logIn,
                  style: const TextStyle(fontSize: 16, color: muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: t.email),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: t.password),
                  obscureText: true,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  ErrorLine(errorMessage),
                ],
                if (authStatus is AuthConfirmationPending) ...[
                  const SizedBox(height: 12),
                  Text(t.confirmEmail, style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isSignUp ? t.signUp : t.logIn),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        t.or,
                        style: const TextStyle(fontSize: 13, color: muted),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => ref
                            .read(authNotifierProvider.notifier)
                            .signInWithApple(),
                  icon: const Icon(Icons.apple),
                  label: Text(t.withApple),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => ref
                            .read(authNotifierProvider.notifier)
                            .signInWithGoogle(),
                  icon: const Icon(Icons.g_mobiledata),
                  label: Text(t.withGoogle),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(_isSignUp ? t.haveAccount : t.noAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
