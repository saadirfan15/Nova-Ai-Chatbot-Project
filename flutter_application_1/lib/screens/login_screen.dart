import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive.dart';

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
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isMobile = Responsive.isMobile(context);
    final screenHeight = Responsive.height(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFEEF4FF)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.horizontalPadding(context),
              vertical: Responsive.height(context) * 0.03,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.cardWidth(context),
              ),
              // constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: EdgeInsets.all(Responsive.isMobile(context) ? 18 : 28),
                // padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        // CircleAvatar(
                        radius: Responsive.avatarRadius(context),
                        backgroundColor: AppTheme.accentSoft,
                        child: Icon(
                          Icons.smart_toy_rounded,
                          color: AppTheme.accent,
                          size: Responsive.isMobile(context) ? 28 : 34,
                          // radius: Responsive.avatarRadius(context),
                          // radius: 28,
                          // backgroundColor: AppTheme.accentSoft,
                          // child: Icon(
                          //   Icons.smart_toy_rounded,
                          //   color: AppTheme.accent,
                          //   size: Responsive.isMobile(context) ? 28 : 34,
                          // size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.titleSize(context),
                              // style: Theme.of(context).textTheme.headlineSmall
                              //     // ?.copyWith(fontWeight: FontWeight.w700),
                              //     .copyWith(
                              //       fontWeight: FontWeight.w700,
                              //       fontSize: Responsive.titleSize(context),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue your AI conversations.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mutedText,
                          fontSize: Responsive.bodySize(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter a username'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter a password'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      if (auth.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _submitLogin,
                          child: auth.isLoading
                              ? const CircularProgressIndicator(
                                  color: AppTheme.deepBackground,
                                )
                              : const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushReplacementNamed('/register'),
                        child: const Text('Create an account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
