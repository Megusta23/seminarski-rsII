import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';

final class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

final class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;
  Map<String, List<String>> _validationErrors =
      const <String, List<String>>{};

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Icon(Icons.mark_email_read_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Request a reset code',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your account email. The response is intentionally the same even when an account does not exist.',
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
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        errorText: _fieldError('email'),
                      ),
                      validator: (String? value) {
                        final String email = value?.trim() ?? '';
                        if (email.isEmpty ||
                            !email.contains('@') ||
                            !email.contains('.')) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_outlined),
                      label: Text(
                        _submitting ? 'Requesting...' : 'Send reset code',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _submitting ? null : () => context.go('/'),
                      child: const Text('Back to sign in'),
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

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _validationErrors = const <String, List<String>>{};
    });

    final String email = _emailController.text.trim();
    try {
      final OperationMessage response =
          await ref.read(authRepositoryProvider).forgotPassword(email);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message)),
      );
      context.go('/reset-password?email=${Uri.encodeComponent(email)}');
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
