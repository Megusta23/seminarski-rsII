import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/todo_visuals.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/todo_widgets.dart';

const Color _formAccent = Color(0xFF675D6D);
const Color _formBorder = Color(0xFFE6E1E8);
const Color _formSurface = Colors.white;

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

  ReferenceItem? get _selectedCategory {
    for (final ReferenceItem category in _categories) {
      if (category.id == _categoryId) {
        return category;
      }
    }
    return _categories.isEmpty ? null : _categories.first;
  }

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
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = values[0] as List<ReferenceItem>;
        _recurrenceTypes = values[1] as List<ReferenceItem>;
        _categoryId ??= _categories.isEmpty ? null : _categories.first.id;
        _recurrenceTypeId ??=
            _recurrenceTypes.isEmpty ? null : _recurrenceTypes.first.id;
        _loadingReferences = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
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
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _dueAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_categoryId == null || _recurrenceTypeId == null) {
      setState(
        () => _error =
            'Categories and recurrence types must be configured first.',
      );
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
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<TaskDetail>(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = ApiException.from(error).message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit task' : 'New task'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loadingReferences
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
                children: <Widget>[
                  _TaskFormSection(
                    title: 'Task',
                    icon: Icons.edit_note_outlined,
                    child: Column(
                      children: <Widget>[
                        TextFormField(
                          controller: _titleController,
                          autofocus: !_isEditing,
                          textInputAction: TextInputAction.next,
                          decoration: _fieldDecoration(
                            label: 'Title',
                            icon: Icons.task_alt,
                          ),
                          maxLength: 200,
                          validator: (String? value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter a task title.'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: _fieldDecoration(
                            label: 'Description',
                            icon: Icons.notes,
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                          maxLength: 2000,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TaskFormSection(
                    title: 'Work block',
                    icon: Icons.palette_outlined,
                    child: LayoutBuilder(
                      builder: (
                        BuildContext context,
                        BoxConstraints constraints,
                      ) {
                        final double width = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _categories
                              .map(
                                (ReferenceItem category) => SizedBox(
                                  width: width,
                                  child: _CategoryOption(
                                    category: category,
                                    selected: category.id == _categoryId,
                                    onTap: _saving
                                        ? null
                                        : () => setState(
                                              () => _categoryId = category.id,
                                            ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TaskFormSection(
                    title: 'Schedule',
                    icon: Icons.calendar_month_outlined,
                    child: Column(
                      children: <Widget>[
                        DropdownButtonFormField<String>(
                          key: ValueKey<String?>(_recurrenceTypeId),
                          initialValue: _recurrenceTypeId,
                          decoration: _fieldDecoration(
                            label: 'Recurrence',
                            icon: Icons.repeat,
                          ),
                          items: _recurrenceTypes
                              .map(
                                (ReferenceItem item) =>
                                    DropdownMenuItem<String>(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _saving
                              ? null
                              : (String? value) =>
                                  setState(() => _recurrenceTypeId = value),
                          validator: (String? value) => value == null
                              ? 'Select a recurrence type.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _DeadlineTile(
                          dueAt: _dueAt,
                          enabled: !_saving,
                          onPick: _pickDueAt,
                          onClear: () => setState(() => _dueAt = null),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TaskFormSection(
                    title: 'Sharing and proof',
                    icon: Icons.people_outline,
                    child: Column(
                      children: <Widget>[
                        _ColoredSwitchTile(
                          title: 'Require proof image',
                          subtitle:
                              'A photo must be attached when completing this task.',
                          value: _requiresProof,
                          icon: Icons.photo_camera_outlined,
                          onChanged: _saving
                              ? null
                              : (bool value) =>
                                  setState(() => _requiresProof = value),
                        ),
                        const SizedBox(height: 10),
                        _ColoredSwitchTile(
                          title: 'Share with friends',
                          subtitle:
                              'Show this task and its completion in accepted friends’ feed.',
                          value: _shareWithFriends,
                          icon: Icons.people_alt_outlined,
                          onChanged: _saving
                              ? null
                              : (bool value) =>
                                  setState(() => _shareWithFriends = value),
                        ),
                      ],
                    ),
                  ),
                  if (_isEditing) ...<Widget>[
                    const SizedBox(height: 16),
                    _TaskFormSection(
                      title: 'Task status',
                      icon: Icons.flag_outlined,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey<int>(_status),
                        initialValue: _status,
                        decoration: _fieldDecoration(
                          label: 'Status',
                          icon: Icons.flag_outlined,
                        ),
                        items: const <DropdownMenuItem<int>>[
                          DropdownMenuItem(
                            value: TaskStatus.active,
                            child: Text('Active'),
                          ),
                          DropdownMenuItem(
                            value: TaskStatus.cancelled,
                            child: Text('Cancelled'),
                          ),
                          DropdownMenuItem(
                            value: TaskStatus.archived,
                            child: Text('Archived'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (int? value) =>
                                setState(() => _status = value ?? _status),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _TaskFormSection(
                    title: 'Preview',
                    icon: Icons.visibility_outlined,
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _titleController,
                      builder: (
                        BuildContext context,
                        TextEditingValue value,
                        Widget? child,
                      ) {
                        return TodoTaskPreview(
                          title: value.text,
                          categoryCode: _selectedCategory?.code ?? '',
                          requiresProof: _requiresProof,
                        );
                      },
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer
                            .withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: _formAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
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

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _formAccent),
    alignLabelWithHint: alignLabelWithHint,
    filled: true,
    fillColor: _formSurface,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _formBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _formAccent, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.red.shade300),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.red.shade400, width: 1.8),
    ),
  );
}

final class _TaskFormSection extends StatelessWidget {
  const _TaskFormSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _formSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _formBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: _formAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

final class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ReferenceItem category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TodoCategoryPalette palette = todoCategoryPalette(category.code);
    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? palette.accent
                  : palette.accent.withValues(alpha: 0.20),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: palette.foreground,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: palette.accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

final class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({
    required this.dueAt,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? dueAt;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _formSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _formBorder),
      ),
      child: ListTile(
        leading: const Icon(Icons.event_outlined, color: _formAccent),
        title: const Text('Deadline'),
        subtitle: Text(dueAt == null ? 'No deadline' : formatDateTime(dueAt!)),
        trailing: Wrap(
          spacing: 2,
          children: <Widget>[
            if (dueAt != null)
              IconButton(
                tooltip: 'Remove deadline',
                onPressed: enabled ? onClear : null,
                icon: const Icon(Icons.clear),
              ),
            IconButton(
              tooltip: 'Select deadline',
              onPressed: enabled ? onPick : null,
              icon: const Icon(Icons.edit_calendar_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ColoredSwitchTile extends StatelessWidget {
  const _ColoredSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final IconData icon;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _formSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _formBorder),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        secondary: Icon(icon, color: _formAccent),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        activeThumbColor: _formAccent,
        onChanged: onChanged,
      ),
    );
  }
}
