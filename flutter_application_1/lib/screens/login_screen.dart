import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in to continue to Nova',
      form: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                label: 'Username',
                icon: Icons.person_outline_rounded,
                controller: _usernameController,
                autofillHints: const [AutofillHints.username],
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your username'
                    : null,
              ),
              const SizedBox(height: 18),
              AuthField(
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                controller: _passwordController,
                isPassword: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitLogin(),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password'
                    : null,
              ),
              const SizedBox(height: 22),
              if (auth.errorMessage != null) ...[
                AuthError(auth.errorMessage!),
                const SizedBox(height: 16),
              ],
              AuthSubmitButton(
                label: 'Sign in',
                busy: auth.isLoading,
                onPressed: _submitLogin,
              ),
            ],
          ),
        ),
      ),
      footer: AuthSwitchLink(
        prompt: 'New to Nova?',
        action: 'Create an account',
        onPressed: () =>
            Navigator.of(context).pushReplacementNamed('/register'),
      ),
    );
  }

  Future<void> _submitLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<AuthProvider>().login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/chat');
    }
  }
}
