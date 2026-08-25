import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/auth/application/auth_state.dart';

final class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

final class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;

  Future<void> _pickAvatar() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    setState(() => _uploading = true);
    try {
      await ref.read(authRepositoryProvider).updateAvatar(
            ImageUpload(
              bytes: bytes,
              fileName: file.name,
              contentType: imageContentType(file.name, file.mimeType),
            ),
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) showMessage(context, 'Profile photo updated.');
    } catch (error) {
      if (mounted) showMessage(context, ApiException.from(error).message, error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeAvatar() async {
    try {
      await ref.read(authRepositoryProvider).removeAvatar();
      ref.invalidate(currentProfileProvider);
      if (mounted) showMessage(context, 'Profile photo removed.');
    } catch (error) {
      if (mounted) showMessage(context, ApiException.from(error).message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MobileAuthState authState = ref.watch(mobileAuthControllerProvider);
    final AsyncValue<CurrentProfile> profile = ref.watch(currentProfileProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(currentProfileProvider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        children: <Widget>[
          profile.when(
            data: (CurrentProfile value) => Column(
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    UserAvatar(
                      displayName: value.displayName,
                      avatarUrl: value.avatarUrl,
                      radius: 58,
                    ),
                    if (_uploading)
                      const Positioned.fill(
                        child: CircularProgressIndicator(),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        tooltip: 'Change profile photo',
                        onPressed: _uploading ? null : _pickAvatar,
                        icon: const Icon(Icons.photo_camera_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(value.displayName, style: Theme.of(context).textTheme.headlineSmall),
                Text(value.email),
                if (value.cityName != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(value.cityName!),
                ],
                if (value.bio != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(value.bio!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () async {
                        await context.push('/edit-profile');
                        ref.invalidate(currentProfileProvider);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                    if (value.avatarUrl != null) ...<Widget>[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _removeAvatar,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove photo'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.cake_outlined),
                        title: const Text('Date of birth'),
                        subtitle: Text(value.dateOfBirth == null
                            ? 'Not provided'
                            : formatDate(value.dateOfBirth!)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Roles'),
                        subtitle: Text(value.roles.join(', ')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) =>
                AppErrorView(error: error, onRetry: () => ref.invalidate(currentProfileProvider)),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Manage highlighted posts'),
                  subtitle: const Text('Feature up to six completed tasks with proof'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/manage-highlights'),
                ),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/change-password'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out'),
                  enabled: !authState.isBusy,
                  onTap: authState.isBusy
                      ? null
                      : () => ref.read(mobileAuthControllerProvider.notifier).logout(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
