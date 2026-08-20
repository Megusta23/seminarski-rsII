import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';

final class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

final class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  String? _loadedUserId;
  String? _selectedCityId;
  DateTime? _dateOfBirth;
  bool _saving = false;
  String? _errorMessage;
  Map<String, List<String>> _validationErrors =
      const <String, List<String>>{};

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CurrentProfile> profileValue =
        ref.watch(currentProfileProvider);
    final AsyncValue<List<CityItem>> citiesValue = ref.watch(citiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: profileValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _LoadError(
          message: ApiException.from(error).message,
          onRetry: () => ref.invalidate(currentProfileProvider),
        ),
        data: (CurrentProfile profile) {
          _initialize(profile);
          return citiesValue.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => _LoadError(
              message: ApiException.from(error).message,
              onRetry: () => ref.invalidate(citiesProvider),
            ),
            data: (List<CityItem> cities) => _buildForm(profile, cities),
          );
        },
      ),
    );
  }

  Widget _buildForm(CurrentProfile profile, List<CityItem> cities) {
    final bool selectedCityExists = _selectedCityId == null ||
        cities.any((CityItem city) => city.id == _selectedCityId);
    if (!selectedCityExists) {
      _selectedCityId = null;
    }

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CircleAvatar(
                    radius: 42,
                    child: Text(
                      _initials(profile),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    profile.email,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
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
                    controller: _firstNameController,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'First name',
                      errorText: _fieldError('firstName'),
                    ),
                    validator: (String? value) {
                      final String text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Enter your first name.';
                      }
                      if (text.length > 100) {
                        return 'Use at most 100 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Last name',
                      errorText: _fieldError('lastName'),
                    ),
                    validator: (String? value) {
                      final String text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Enter your last name.';
                      }
                      if (text.length > 100) {
                        return 'Use at most 100 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'Biography',
                      alignLabelWithHint: true,
                      errorText: _fieldError('bio'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedCityId,
                    decoration: InputDecoration(
                      labelText: 'City',
                      errorText: _fieldError('cityId'),
                    ),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No city selected'),
                      ),
                      ...cities.map(
                        (CityItem city) => DropdownMenuItem<String?>(
                          value: city.id,
                          child: Text('${city.name}, ${city.countryName}'),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (String? value) =>
                            setState(() => _selectedCityId = value),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of birth',
                      errorText: _fieldError('dateOfBirth'),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _dateOfBirth == null
                                ? 'Not provided'
                                : _formatDate(_dateOfBirth!),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _saving ? null : _pickDate,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: const Text('Select'),
                        ),
                        if (_dateOfBirth != null)
                          IconButton(
                            tooltip: 'Clear date',
                            onPressed: _saving
                                ? null
                                : () => setState(() => _dateOfBirth = null),
                            icon: const Icon(Icons.clear),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _initialize(CurrentProfile profile) {
    if (_loadedUserId == profile.userId) {
      return;
    }

    _loadedUserId = profile.userId;
    _firstNameController.text = profile.firstName;
    _lastNameController.text = profile.lastName;
    _bioController.text = profile.bio ?? '';
    _selectedCityId = profile.cityId;
    _dateOfBirth = profile.dateOfBirth;
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (selected != null && mounted) {
      setState(() => _dateOfBirth = selected);
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
      _validationErrors = const <String, List<String>>{};
    });

    try {
      await ref.read(authRepositoryProvider).updateCurrentProfile(
            firstName: _firstNameController.text,
            lastName: _lastNameController.text,
            bio: _bioController.text,
            cityId: _selectedCityId,
            dateOfBirth: _dateOfBirth,
          );
      ref.invalidate(currentProfileProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.of(context).pop();
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
        setState(() => _saving = false);
      }
    }
  }

  String _initials(CurrentProfile profile) {
    final String first = profile.firstName.trim();
    final String last = profile.lastName.trim();
    return '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}'
        .toUpperCase();
  }

  String _formatDate(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
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

final class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
