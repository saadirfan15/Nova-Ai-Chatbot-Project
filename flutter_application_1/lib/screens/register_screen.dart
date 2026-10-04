import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AuthShell(
      title: 'Create your account',
      subtitle: 'Start chatting with Nova in seconds',
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
                autofillHints: const [AutofillHints.newUsername],
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Choose a username'
                    : null,
              ),
              const SizedBox(height: 18),
              AuthField(
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Enter your email';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthField(
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                controller: _passwordController,
                isPassword: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitRegister(),
                // Mirrors the backend's min_length=8 on the serializer.
                validator: (value) => (value?.length ?? 0) < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 22),
              if (auth.errorMessage != null) ...[
                AuthError(auth.errorMessage!),
                const SizedBox(height: 16),
              ],
              AuthSubmitButton(
                label: 'Create account',
                busy: auth.isLoading,
                onPressed: _submitRegister,
              ),
            ],
          ),
        ),
      ),
      footer: AuthSwitchLink(
        prompt: 'Already have an account?',
        action: 'Sign in',
        onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
      ),
    );
  }

  Future<void> _submitRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await context.read<AuthProvider>().register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/chat');
    }
  }
}
