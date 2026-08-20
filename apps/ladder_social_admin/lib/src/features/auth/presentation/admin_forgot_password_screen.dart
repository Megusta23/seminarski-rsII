import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/features/auth/presentation/admin_reset_password_screen.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

final class AdminForgotPasswordScreen extends ConsumerStatefulWidget {
  const AdminForgotPasswordScreen({super.key});

  @override
  ConsumerState<AdminForgotPasswordScreen> createState() =>
      _AdminForgotPasswordScreenState();
}

final class _AdminForgotPasswordScreenState
    extends ConsumerState<AdminForgotPasswordScreen> {
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
      appBar: AppBar(title: const Text('Administrator password recovery')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Icon(Icons.mark_email_read_outlined, size: 72),
                  const SizedBox(height: 20),
                  Text(
                    'Request a reset code',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A reset email is sent through the configured mail service. Local development uses smtp4dev.',
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
                      labelText: 'Administrator email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      errorText: _fieldError('email'),
                    ),
                    validator: (String? value) {
                      final String email = value?.trim() ?? '';
                      return email.contains('@') && email.contains('.')
                          ? null
                          : 'Enter a valid email address.';
                    },
                  ),
                  const SizedBox(height: 22),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              AdminResetPasswordScreen(initialEmail: email),
        ),
      );
    } catch (error) {
      final ApiException exception = ApiException.from(error);
      if (mounted) {
        setState(() {
          _errorMessage = exception.message;
          _validationErrors = exception.validationErrors;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
