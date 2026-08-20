import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

final class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({this.initialTask, super.key});

  final TaskDetail? initialTask;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

final class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  List<ReferenceItem> _categories = const <ReferenceItem>[];
  List<ReferenceItem> _recurrenceTypes = const <ReferenceItem>[];
  String? _categoryId;
  String? _recurrenceTypeId;
  DateTime? _dueAt;
  bool _requiresProof = false;
  bool _shareWithFriends = false;
  int _status = TaskStatus.active;
  bool _loadingReferences = true;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initialTask != null;

  @override
  void initState() {
    super.initState();
    final TaskDetail? task = widget.initialTask;
    _titleController = TextEditingController(text: task?.title);
    _descriptionController = TextEditingController(text: task?.description);
    _categoryId = task?.taskCategoryId;
    _recurrenceTypeId = task?.recurrenceTypeId;
    _dueAt = task?.dueAtUtc?.toLocal();
    _requiresProof = task?.requiresProofImage ?? false;
    _shareWithFriends = task?.shareWithFriends ?? false;
    _status = task?.status ?? TaskStatus.active;
    _loadReferences();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    try {
      final List<Object> values = await Future.wait<Object>(<Future<Object>>[
        ref.read(referenceDataRepositoryProvider).getTaskCategories(),
        ref.read(referenceDataRepositoryProvider).getRecurrenceTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = values[0] as List<ReferenceItem>;
        _recurrenceTypes = values[1] as List<ReferenceItem>;
        _categoryId ??= _categories.isEmpty ? null : _categories.first.id;
        _recurrenceTypeId ??=
            _recurrenceTypes.isEmpty ? null : _recurrenceTypes.first.id;
        _loadingReferences = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingReferences = false;
        _error = ApiException.from(error).message;
      });
    }
  }

  Future<void> _pickDueAt() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _dueAt ?? now.add(const Duration(hours: 1));
    final DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      initialDate: initial,
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null || _recurrenceTypeId == null) {
      setState(() => _error = 'Categories and recurrence types must be configured first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final TaskDraft draft = TaskDraft(
        title: _titleController.text,
        description: _descriptionController.text,
        taskCategoryId: _categoryId!,
        recurrenceTypeId: _recurrenceTypeId!,
        dueAtUtc: _dueAt,
        requiresProofImage: _requiresProof,
        shareWithFriends: _shareWithFriends,
        status: _status,
      );
      final TaskRepository repository = ref.read(taskRepositoryProvider);
      final TaskDetail saved = _isEditing
          ? await repository.updateTask(widget.initialTask!.id, draft)
          : await repository.createTask(draft);
      if (!mounted) return;
      Navigator.of(context).pop<TaskDetail>(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ApiException.from(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit task' : 'New task')),
      body: _loadingReferences
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  TextFormField(
                    controller: _titleController,
                    autofocus: !_isEditing,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.task_alt),
                    ),
                    maxLength: 200,
                    validator: (String? value) => value == null || value.trim().isEmpty
                        ? 'Enter a task title.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.notes),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    maxLength: 2000,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _categories
                        .map((ReferenceItem item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(item.name),
                            ))
                        .toList(growable: false),
                    onChanged: _saving
                        ? null
                        : (String? value) => setState(() => _categoryId = value),
                    validator: (String? value) =>
                        value == null ? 'Select a category.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _recurrenceTypeId,
                    decoration: const InputDecoration(
                      labelText: 'Recurrence',
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    items: _recurrenceTypes
                        .map((ReferenceItem item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(item.name),
                            ))
                        .toList(growable: false),
                    onChanged: _saving
                        ? null
                        : (String? value) =>
                            setState(() => _recurrenceTypeId = value),
                    validator: (String? value) =>
                        value == null ? 'Select a recurrence type.' : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Deadline'),
                    subtitle: Text(
                      _dueAt == null ? 'No deadline' : formatDateTime(_dueAt!),
                    ),
                    trailing: Wrap(
                      children: <Widget>[
                        if (_dueAt != null)
                          IconButton(
                            tooltip: 'Remove deadline',
                            onPressed: () => setState(() => _dueAt = null),
                            icon: const Icon(Icons.clear),
                          ),
                        IconButton(
                          tooltip: 'Select deadline',
                          onPressed: _pickDueAt,
                          icon: const Icon(Icons.edit_calendar_outlined),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Require proof image'),
                    subtitle: const Text('A photo must be attached when completing this task.'),
                    value: _requiresProof,
                    onChanged: _saving
                        ? null
                        : (bool value) => setState(() => _requiresProof = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Share with friends'),
                    subtitle: const Text('Create a feed post when the task is completed.'),
                    value: _shareWithFriends,
                    onChanged: _saving
                        ? null
                        : (bool value) => setState(() => _shareWithFriends = value),
                  ),
                  if (_isEditing) ...<Widget>[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem(value: TaskStatus.active, child: Text('Active')),
                        DropdownMenuItem(value: TaskStatus.cancelled, child: Text('Cancelled')),
                        DropdownMenuItem(value: TaskStatus.archived, child: Text('Archived')),
                      ],
                      onChanged: _saving
                          ? null
                          : (int? value) => setState(() => _status = value ?? _status),
                    ),
                  ],
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isEditing ? 'Save changes' : 'Create task'),
                  ),
                ],
              ),
            ),
    );
  }
}
