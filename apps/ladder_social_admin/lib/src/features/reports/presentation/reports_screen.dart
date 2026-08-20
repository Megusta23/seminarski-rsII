import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/core/widgets/admin_widgets.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

final class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

final class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  late DateTime _toDate = DateTime.now();
  final TextEditingController _userSearch = TextEditingController();
  Future<PagedResult<AdminUserItem>>? _users;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _userSearch.dispose();
    super.dispose();
  }

  void _loadUsers() {
    setState(() {
      _users = ref.read(adminRepositoryProvider).getUsers(
            search: _userSearch.text,
            pageSize: 50,
          );
    });
  }

  Future<void> _pickDate(bool from) async {
    final DateTime? value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: from ? _fromDate : _toDate,
    );
    if (value == null) return;
    setState(() {
      if (from) {
        _fromDate = value;
      } else {
        _toDate = value;
      }
    });
  }

  Future<void> _save(DownloadedFile report) async {
    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: report.fileName,
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(label: 'PDF document', extensions: <String>['pdf']),
      ],
    );
    if (location == null) return;
    await File(location.path).writeAsBytes(report.bytes, flush: true);
    if (mounted) adminMessage(context, 'Report saved to ${location.path}');
  }

  Future<void> _activity() async {
    if (_toDate.isBefore(_fromDate)) {
      adminMessage(context, 'The end date must not be before the start date.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final DownloadedFile report = await ref.read(adminRepositoryProvider).downloadActivityReport(
            fromDate: _fromDate,
            toDate: _toDate,
          );
      await _save(report);
    } catch (error) {
      if (mounted) adminMessage(context, ApiException.from(error).message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _user(AdminUserItem user) async {
    setState(() => _busy = true);
    try {
      final DownloadedFile report = await ref.read(adminRepositoryProvider).downloadUserReport(user.id);
      await _save(report);
    } catch (error) {
      if (mounted) adminMessage(context, ApiException.from(error).message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AdminPageHeader(
            title: 'PDF reports',
            subtitle: 'Generate, download and print the two required administrative reports.',
          ),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Application activity report', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        const Text('Users, tasks, completions, posts and top performers in a selected period.'),
                        const SizedBox(height: 18),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: ListTile(
                                leading: const Icon(Icons.calendar_today_outlined),
                                title: const Text('From'),
                                subtitle: Text(adminDate(_fromDate)),
                                onTap: () => _pickDate(true),
                              ),
                            ),
                            Expanded(
                              child: ListTile(
                                leading: const Icon(Icons.event_outlined),
                                title: const Text('To'),
                                subtitle: Text(adminDate(_toDate)),
                                onTap: () => _pickDate(false),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _busy ? null : _activity,
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('Generate PDF'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Individual user activity report', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        const Text('Profile details, friendships, tasks, completions, posts and recent activity.'),
                        const SizedBox(height: 16),
                        SearchBar(
                          controller: _userSearch,
                          hintText: 'Search user by name or email',
                          leading: const Icon(Icons.search),
                          onSubmitted: (_) => _loadUsers(),
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<PagedResult<AdminUserItem>>(
                          future: _users,
                          builder: (BuildContext context, AsyncSnapshot<PagedResult<AdminUserItem>> snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                            if (snapshot.hasError) return AdminErrorView(error: snapshot.error!, onRetry: _loadUsers);
                            if (snapshot.data!.items.isEmpty) return const Text('No users match the search.');
                            return Column(
                              children: snapshot.data!.items
                                  .map((AdminUserItem user) => ListTile(
                                        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                                        title: Text(user.displayName),
                                        subtitle: Text(user.email),
                                        trailing: IconButton(
                                          tooltip: 'Generate user PDF',
                                          onPressed: _busy ? null : () => _user(user),
                                          icon: const Icon(Icons.picture_as_pdf_outlined),
                                        ),
                                      ))
                                  .toList(growable: false),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
