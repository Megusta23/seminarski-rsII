import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/features/auth/application/auth_state.dart';

final class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

final class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MobileAuthState>(
      mobileAuthControllerProvider,
      (MobileAuthState? previous, MobileAuthState next) {
        if (next.isAuthenticated && context.mounted) {
          context.go('/');
        }
      },
    );

    final MobileAuthState authState =
        ref.watch(mobileAuthControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: authState.isBusy
              ? null
              : () {
                  ref
                      .read(mobileAuthControllerProvider.notifier)
                      .clearErrors();
                  context.go('/');
                },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
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
                      'Join Ladder Social',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A new account always receives the regular User role.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (authState.errorMessage != null) ...<Widget>[
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(authState.errorMessage!),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            enabled: !authState.isBusy,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'First name',
                              errorText: authState.fieldError('firstName'),
                            ),
                            validator: (String? value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Required.'
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            enabled: !authState.isBusy,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Last name',
                              errorText: authState.fieldError('lastName'),
                            ),
                            validator: (String? value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Required.'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      enabled: !authState.isBusy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        errorText: authState.fieldError('email'),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !authState.isBusy,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText:
                            'At least 10 characters with upper/lowercase, number and symbol.',
                        errorText: authState.fieldError('password'),
                        suffixIcon: IconButton(
                          onPressed: authState.isBusy
                              ? null
                              : () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (String? value) =>
                          value == null || value.length < 10
                              ? 'Use at least 10 characters.'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      enabled: !authState.isBusy,
                      obscureText: _hideConfirmation,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        errorText: authState.fieldError('confirmPassword'),
                        suffixIcon: IconButton(
                          onPressed: authState.isBusy
                              ? null
                              : () => setState(
                                    () => _hideConfirmation =
                                        !_hideConfirmation,
                                  ),
                          icon: Icon(
                            _hideConfirmation
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (String? value) =>
                          value != _passwordController.text
                              ? 'Passwords must match.'
                              : null,
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: authState.isBusy ? null : _submit,
                      icon: authState.isBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: Text(
                        authState.isBusy
                            ? 'Creating account...'
                            : 'Create account',
                      ),
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(mobileAuthControllerProvider.notifier).register(
          email: _emailController.text,
          password: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
        );
  }
}
