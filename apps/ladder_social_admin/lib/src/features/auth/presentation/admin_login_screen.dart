import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/features/auth/application/admin_auth_state.dart';

final class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

final class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AdminAuthState authState = ref.watch(adminAuthControllerProvider);

    return Scaffold(
      body: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.stairs_outlined, size: 96),
                      SizedBox(height: 24),
                      Text(
                        'Ladder Social Admin',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Secure administrator access for analytics, users, '
                        'reference data and reports.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Administrator sign in',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Only accounts with the Admin role can open the desktop application.',
                        ),
                        const SizedBox(height: 28),
                        if (authState.errorMessage != null) ...<Widget>[
                          Card(
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text(authState.errorMessage!),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _emailController,
                          enabled: !authState.isBusy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Administrator email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            errorText: authState.fieldError('email'),
                          ),
                          validator: (String? value) {
                            final String email = value?.trim() ?? '';
                            if (email.isEmpty || !email.contains('@')) {
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
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(authState),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            errorText: authState.fieldError('password'),
                            suffixIcon: IconButton(
                              tooltip: _hidePassword
                                  ? 'Show password'
                                  : 'Hide password',
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
                              value == null || value.isEmpty
                                  ? 'Enter your password.'
                                  : null,
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: authState.isBusy
                              ? null
                              : () => _submit(authState),
                          icon: authState.isBusy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.admin_panel_settings),
                          label: Text(
                            authState.isBusy
                                ? 'Signing in...'
                                : 'Sign in as administrator',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Use SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD from your local .env file.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(AdminAuthState authState) async {
    if (authState.isBusy || !_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(adminAuthControllerProvider.notifier).login(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }
}
