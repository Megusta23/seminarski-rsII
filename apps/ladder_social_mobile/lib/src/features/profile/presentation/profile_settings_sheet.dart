import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/auth/application/auth_state.dart';

enum ProfileSettingsChoice {
  editProfile,
  changePhoto,
  removePhoto,
  manageHighlights,
  changePassword,
  logout,
}

final class ProfileSettingsAction extends ConsumerStatefulWidget {
  const ProfileSettingsAction({super.key});

  @override
  ConsumerState<ProfileSettingsAction> createState() =>
      _ProfileSettingsActionState();
}

final class _ProfileSettingsActionState
    extends ConsumerState<ProfileSettingsAction> {
  bool _busy = false;

  void _refreshProfileData() {
    ref.invalidate(currentProfileProvider);
    ref.invalidate(ownProfileOverviewProvider);
  }

  Future<void> _openMenu() async {
    if (_busy) {
      return;
    }

    final CurrentProfile? profile =
        ref.read(currentProfileProvider).asData?.value;
    final ProfileSettingsChoice? choice =
        await showModalBottomSheet<ProfileSettingsChoice>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (BuildContext context) => ProfileSettingsSheet(
        hasAvatar: profile?.avatarUrl?.isNotEmpty == true,
      ),
    );

    if (!mounted || choice == null) {
      return;
    }

    switch (choice) {
      case ProfileSettingsChoice.editProfile:
        await context.push('/edit-profile');
        if (mounted) {
          _refreshProfileData();
        }
        return;
      case ProfileSettingsChoice.changePhoto:
        await _pickAvatar();
        return;
      case ProfileSettingsChoice.removePhoto:
        await _removeAvatar();
        return;
      case ProfileSettingsChoice.manageHighlights:
        await context.push('/manage-highlights');
        if (mounted) {
          _refreshProfileData();
        }
        return;
      case ProfileSettingsChoice.changePassword:
        await context.push('/change-password');
        return;
      case ProfileSettingsChoice.logout:
        await _confirmLogout();
        return;
    }
  }

  Future<void> _pickAvatar() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (file == null || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      final Uint8List bytes = await file.readAsBytes();
      await ref.read(authRepositoryProvider).updateAvatar(
            ImageUpload(
              bytes: bytes,
              fileName: file.name,
              contentType: imageContentType(file.name, file.mimeType),
            ),
          );
      if (!mounted) {
        return;
      }
      _refreshProfileData();
      showMessage(context, 'Profile photo updated.');
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _removeAvatar() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Remove profile photo?'),
        content: const Text(
          'Your initials will be shown until you add another profile photo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove photo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
    });
    try {
      await ref.read(authRepositoryProvider).removeAvatar();
      if (!mounted) {
        return;
      }
      _refreshProfileData();
      showMessage(context, 'Profile photo removed.');
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _confirmLogout() async {
    final MobileAuthState state = ref.read(mobileAuthControllerProvider);
    if (state.isBusy) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use Ladder Social.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(mobileAuthControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('profile-settings-button'),
      tooltip: 'Profile settings',
      onPressed: _busy ? null : _openMenu,
      icon: _busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.menu_rounded),
    );
  }
}

final class ProfileSettingsSheet extends StatelessWidget {
  const ProfileSettingsSheet({required this.hasAvatar, super.key});

  final bool hasAvatar;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('profile-settings-sheet'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
              child: Text(
                'Profile settings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            _SettingsTile(
              key: const Key('profile-menu-edit'),
              icon: Icons.edit_outlined,
              title: 'Edit profile',
              subtitle: 'Name, biography, city and date of birth',
              onTap: () => Navigator.pop(
                context,
                ProfileSettingsChoice.editProfile,
              ),
            ),
            _SettingsTile(
              key: const Key('profile-menu-change-photo'),
              icon: Icons.add_a_photo_outlined,
              title: 'Change profile picture',
              subtitle: 'Choose a new image from your gallery',
              onTap: () => Navigator.pop(
                context,
                ProfileSettingsChoice.changePhoto,
              ),
            ),
            if (hasAvatar)
              _SettingsTile(
                key: const Key('profile-menu-remove-photo'),
                icon: Icons.hide_image_outlined,
                title: 'Remove profile picture',
                onTap: () => Navigator.pop(
                  context,
                  ProfileSettingsChoice.removePhoto,
                ),
              ),
            _SettingsTile(
              key: const Key('profile-menu-highlights'),
              icon: Icons.auto_awesome_outlined,
              title: 'Manage highlighted posts',
              subtitle: 'Choose up to six completed proof posts',
              onTap: () => Navigator.pop(
                context,
                ProfileSettingsChoice.manageHighlights,
              ),
            ),
            _SettingsTile(
              key: const Key('profile-menu-password'),
              icon: Icons.lock_outline,
              title: 'Change password',
              onTap: () => Navigator.pop(
                context,
                ProfileSettingsChoice.changePassword,
              ),
            ),
            const Divider(height: 22),
            _SettingsTile(
              key: const Key('profile-menu-logout'),
              icon: Icons.logout,
              title: 'Log out',
              destructive: true,
              onTap: () => Navigator.pop(
                context,
                ProfileSettingsChoice.logout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color? color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
