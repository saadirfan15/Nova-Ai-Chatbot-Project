import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'aurora_effects.dart';

/// Shared layout for the sign-in and sign-up screens.
class AuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;

  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RiseIn(
                      child: Column(
                        children: [
                          const Floating(child: NovaLogo(size: 64, glow: true)),
                          const SizedBox(height: 26),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AppTheme.display(28),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    RiseIn(
                      delay: const Duration(milliseconds: 200),
                      child: form,
                    ),
                    const SizedBox(height: 28),
                    RiseIn(
                      delay: const Duration(milliseconds: 400),
                      child: footer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Labelled text field with a leading icon and, for passwords, a show/hide
/// toggle.
class AuthField extends StatefulWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  const AuthField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.validator,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.body,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword && _obscured,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHints,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          style: const TextStyle(fontSize: 15, color: AppTheme.text),
          decoration: InputDecoration(
            prefixIcon: Icon(widget.icon, size: 19),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscured = !_obscured),
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Error banner shown above the submit button.
class AuthError extends StatelessWidget {
  final String message;
  const AuthError(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppTheme.danger.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: AppTheme.danger,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppTheme.danger, fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

/// Primary submit button with a spinner while busy.
class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: AppTheme.accent.withValues(alpha: 0.3),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: ElevatedButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppTheme.onAccent,
              ),
            )
          : Text(label),
    ),
  );
}

/// "New to Nova? Create an account" style footer link.
class AuthSwitchLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onPressed;
  const AuthSwitchLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        prompt,
        style: const TextStyle(color: AppTheme.muted, fontSize: 14.5),
      ),
      TextButton(
        onPressed: onPressed,
        child: Text(
          action,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
    ],
  );
}
