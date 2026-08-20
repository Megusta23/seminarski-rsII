import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';

final class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

final class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  bool _submitting = false;
  String? _errorMessage;
  Map<String, List<String>> _validationErrors =
      const <String, List<String>>{};

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Enter the six-digit code',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check the account inbox. In local development, the message appears in smtp4dev on your Mac.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...<Widget>[
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(_errorMessage!),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        errorText: _fieldError('email'),
                      ),
                      validator: (String? value) {
                        final String email = value?.trim() ?? '';
                        return email.contains('@') && email.contains('.')
                            ? null
                            : 'Enter a valid email address.';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _codeController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Reset code',
                        prefixIcon: const Icon(Icons.pin_outlined),
                        errorText: _fieldError('code'),
                        counterText: '',
                      ),
                      validator: (String? value) =>
                          RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                              ? null
                              : 'Enter exactly six digits.',
                    ),
                    const SizedBox(height: 16),
                    _passwordField(
                      controller: _passwordController,
                      label: 'New password',
                      hidden: _hidePassword,
                      fieldError: _fieldError('newPassword'),
                      onToggle: () =>
                          setState(() => _hidePassword = !_hidePassword),
                    ),
                    const SizedBox(height: 16),
                    _passwordField(
                      controller: _confirmationController,
                      label: 'Confirm new password',
                      hidden: _hideConfirmation,
                      fieldError: _fieldError('confirmPassword'),
                      onToggle: () => setState(
                        () => _hideConfirmation = !_hideConfirmation,
                      ),
                      confirmation: true,
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.password_outlined),
                      label: Text(
                        _submitting ? 'Resetting...' : 'Reset password',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => context.go('/forgot-password'),
                      child: const Text('Request another code'),
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

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required VoidCallback onToggle,
    required String? fieldError,
    bool confirmation = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_submitting,
      obscureText: hidden,
      textInputAction:
          confirmation ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: confirmation ? (_) => _submit() : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: confirmation
            ? null
            : 'At least 10 characters with upper/lowercase, number and symbol.',
        errorText: fieldError,
        suffixIcon: IconButton(
          onPressed: _submitting ? null : onToggle,
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: (String? value) {
        if (confirmation) {
          return value == _passwordController.text
              ? null
              : 'Passwords must match.';
        }
        return value != null && value.length >= 10
            ? null
            : 'Use at least 10 characters.';
      },
    );
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _validationErrors = const <String, List<String>>{};
    });

    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: _emailController.text,
            code: _codeController.text,
            newPassword: _passwordController.text,
            confirmPassword: _confirmationController.text,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset. Sign in with your new password.'),
        ),
      );
      context.go('/');
    } catch (error) {
      final ApiException exception = ApiException.from(error);
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = exception.message;
        _validationErrors = exception.validationErrors;
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String? _fieldError(String field) {
    for (final MapEntry<String, List<String>> entry
        in _validationErrors.entries) {
      if (entry.key.toLowerCase() == field.toLowerCase() &&
          entry.value.isNotEmpty) {
        return entry.value.join('\n');
      }
    }
    return null;
  }
}
