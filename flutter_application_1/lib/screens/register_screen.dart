import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive.dart';

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
              vertical: screenHeight * 0.03,
            ),
            // padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.cardWidth(context),
              ),
              // constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 18 : 28),
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
                        radius: Responsive.avatarRadius(context),
                        // radius: 28,
                        backgroundColor: AppTheme.accentSoft,
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppTheme.accent,
                          size: isMobile ? 28 : 34,
                          // size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Create account',
                        style: Theme.of(context).textTheme.headlineSmall
                            // ?.copyWith(fontWeight: FontWeight.w700),
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.titleSize(context),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join the sleek AI chat experience.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mutedText,
                          fontSize: Responsive.bodySize(context),
                          // style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          //   color: AppTheme.mutedText,
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
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter an email'
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
                        height: Responsive.buttonHeight(context),
                        // SizedBox(
                        //   width: double.infinity,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _submitRegister,
                          child: auth.isLoading
                              ? const CircularProgressIndicator(
                                  color: AppTheme.deepBackground,
                                )
                              : const Text('Create account'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushReplacementNamed('/login'),
                        child: const Text('Already have an account?'),
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

  Future<void> _submitRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    print("HI");
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
