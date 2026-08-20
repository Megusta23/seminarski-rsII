import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/features/auth/application/admin_auth_state.dart';

final class AdminChangePasswordScreen extends ConsumerStatefulWidget {
  const AdminChangePasswordScreen({super.key});

  @override
  ConsumerState<AdminChangePasswordScreen> createState() =>
      _AdminChangePasswordScreenState();
}

final class _AdminChangePasswordScreenState
    extends ConsumerState<AdminChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirmation = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AdminAuthState state = ref.watch(adminAuthControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Change administrator password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'All active sessions are revoked after the password changes.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (state.errorMessage != null) ...<Widget>[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(state.errorMessage!),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _field(
                    controller: _currentController,
                    label: 'Current password',
                    hidden: _hideCurrent,
                    errorText: state.fieldError('currentPassword'),
                    onToggle: () =>
                        setState(() => _hideCurrent = !_hideCurrent),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    controller: _newController,
                    label: 'New password',
                    hidden: _hideNew,
                    errorText: state.fieldError('newPassword'),
                    onToggle: () => setState(() => _hideNew = !_hideNew),
                    newPassword: true,
                  ),
                  const SizedBox(height: 16),
                  _field(
                    controller: _confirmationController,
                    label: 'Confirm new password',
                    hidden: _hideConfirmation,
                    errorText: state.fieldError('confirmPassword'),
                    onToggle: () => setState(
                      () => _hideConfirmation = !_hideConfirmation,
                    ),
                    confirmation: true,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: state.isBusy ? null : _submit,
                    icon: state.isBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.password_outlined),
                    label: Text(
                      state.isBusy ? 'Changing...' : 'Change password',
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool hidden,
    required String? errorText,
    required VoidCallback onToggle,
    bool newPassword = false,
    bool confirmation = false,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !ref.read(adminAuthControllerProvider).isBusy,
      obscureText: hidden,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        helperText: newPassword
            ? 'At least 10 characters with upper/lowercase, number and symbol.'
            : null,
        suffixIcon: IconButton(
          onPressed: ref.read(adminAuthControllerProvider).isBusy
              ? null
              : onToggle,
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: (String? value) {
        if (confirmation) {
          return value == _newController.text ? null : 'Passwords must match.';
        }
        if (value == null || value.isEmpty) {
          return 'Required.';
        }
        if (newPassword && value.length < 10) {
          return 'Use at least 10 characters.';
        }
        return null;
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final bool changed = await ref
        .read(adminAuthControllerProvider.notifier)
        .changePassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
          confirmPassword: _confirmationController.text,
        );

    if (changed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed. Sign in again.'),
        ),
      );
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    }
  }
}
