import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/proof_capture_screen.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/proof_composer.dart';

const Color _completionBackground = Color(0xFFFFF8FF);
const Color _completionBorder = Color(0xFFE7DFE9);
const Color _completionOrange = Color(0xFFFFA62B);
const Color _completionPurple = Color(0xFFA64EC4);

final class CompleteTaskScreen extends ConsumerStatefulWidget {
  const CompleteTaskScreen({required this.task, super.key});

  final TaskDetail task;

  @override
  ConsumerState<CompleteTaskScreen> createState() => _CompleteTaskScreenState();
}

final class _CompleteTaskScreenState extends ConsumerState<CompleteTaskScreen> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();

  CompletionDateOptions? _dateOptions;
  DateTime? _occurrenceDate;
  ProofComposition? _proof;
  bool _dateOptionsRequested = false;
  bool _loadingDates = true;
  bool _saving = false;
  String? _dateError;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dateOptionsRequested) {
      return;
    }
    _dateOptionsRequested = true;
    _loadDateOptions();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadDateOptions() async {
    if (mounted) {
      setState(() {
        _loadingDates = true;
        _dateError = null;
      });
    }

    try {
      final CompletionDateOptions options = await ref
          .read(taskRepositoryProvider)
          .getCompletionDateOptions(widget.task.id);
      if (!mounted) {
        return;
      }

      final List<DateTime> dates = options.allowedDates.toList(growable: false)
        ..sort();
      final DateTime? selected = dates.isEmpty
          ? null
          : dates.any(
              (DateTime date) => _isSameDate(date, options.businessDate),
            )
              ? options.businessDate
              : dates.last;
      setState(() {
        _dateOptions = CompletionDateOptions(
          businessDate: options.businessDate,
          recurrenceAnchorDate: options.recurrenceAnchorDate,
          recurrenceCode: options.recurrenceCode,
          allowedDates: dates,
        );
        _occurrenceDate = selected;
        _loadingDates = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingDates = false;
        _dateError = ApiException.from(error).message;
      });
    }
  }

  Future<void> _pickDate() async {
    final CompletionDateOptions? options = _dateOptions;
    final DateTime? current = _occurrenceDate;
    if (options == null || current == null || options.allowedDates.isEmpty) {
      return;
    }

    final Set<String> allowed = options.allowedDates.map(_dateKey).toSet();
    final DateTime? value = await showDatePicker(
      context: context,
      firstDate: options.allowedDates.first,
      lastDate: options.businessDate,
      initialDate: current,
      selectableDayPredicate: (DateTime date) =>
          allowed.contains(_dateKey(date)),
      helpText: 'Select a valid task occurrence',
    );
    if (value != null && mounted) {
      setState(() => _occurrenceDate = DateUtils.dateOnly(value));
    }
  }

  Future<void> _openProofComposer() async {
    final ProofComposition? proof = await Navigator.of(context).push(
      MaterialPageRoute<ProofComposition>(
        fullscreenDialog: true,
        builder: (_) => ProofCaptureScreen(initialComposition: _proof),
      ),
    );
    if (proof != null && mounted) {
      setState(() {
        _proof = proof;
        _error = null;
      });
    }
  }

  Future<void> _complete() async {
    final DateTime? occurrenceDate = _occurrenceDate;
    if (occurrenceDate == null) {
      setState(() {
        _error =
            'There is no valid unfinished occurrence available for this task.';
      });
      return;
    }

    final ProofComposition? proof = _proof;
    if (widget.task.requiresProofImage && proof == null) {
      setState(() {
        _error = 'Add a photo proof before marking this task completed.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      ImageUpload? cover;
      List<ImageUpload> sourceUploads = const <ImageUpload>[];
      String? layoutCode;

      if (proof != null) {
        cover = ImageUpload(
          bytes: proof.coverBytes,
          fileName: 'proof-cover-${DateTime.now().microsecondsSinceEpoch}.png',
          contentType: 'image/png',
        );
        sourceUploads = proof.photos.map(_toUpload).toList(growable: false);
        layoutCode = proof.layoutCode;
      }

      final TaskCompletionItem completion =
          await ref.read(taskRepositoryProvider).completeTask(
                taskId: widget.task.id,
                occurrenceDate: occurrenceDate,
                note: _noteController.text,
                caption: _captionController.text,
                proofLayoutCode: layoutCode,
                proof: cover,
                proofImages: sourceUploads,
              );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<TaskCompletionItem>(completion);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  ImageUpload _toUpload(EditableProofPhoto photo) {
    final String contentType = proofImageContentType(photo.bytes);
    return ImageUpload(
      bytes: photo.bytes,
      fileName: proofImageFileName(photo.fileName, contentType),
      contentType: contentType,
    );
  }

  String _friendlyError(Object error) {
    final ApiException exception = ApiException.from(error);
    final List<String> validationMessages = exception.validationErrors.values
        .expand((List<String> values) => values)
        .where((String value) => value.trim().isNotEmpty)
        .toList(growable: false);
    return validationMessages.isEmpty
        ? exception.message
        : validationMessages.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDates) {
      return Scaffold(
        backgroundColor: _completionBackground,
        appBar: AppBar(
          backgroundColor: _completionBackground,
          title: const Text('Complete task'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_dateError != null) {
      return Scaffold(
        backgroundColor: _completionBackground,
        appBar: AppBar(
          backgroundColor: _completionBackground,
          title: const Text('Complete task'),
        ),
        body: AppErrorView(error: _dateError!, onRetry: _loadDateOptions),
      );
    }

    final CompletionDateOptions options = _dateOptions!;
    final bool hasAllowedDate = _occurrenceDate != null;

    return Scaffold(
      backgroundColor: _completionBackground,
      appBar: AppBar(
        backgroundColor: _completionBackground,
        title: const Text('Complete task'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: <Widget>[
          _TaskHeader(task: widget.task),
          const SizedBox(height: 14),
          _SectionCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF0E8F4),
                foregroundColor: Color(0xFF67506F),
                child: Icon(Icons.today_outlined),
              ),
              title: const Text(
                'Occurrence date',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                hasAllowedDate
                    ? '${formatDate(_occurrenceDate!)} • UTC business date'
                    : 'No unfinished occurrence is available.',
              ),
              trailing: IconButton(
                onPressed: hasAllowedDate && !_saving ? _pickDate : null,
                tooltip: 'Choose a valid occurrence date',
                icon: const Icon(Icons.edit_calendar_outlined),
              ),
            ),
          ),
          if (!hasAllowedDate) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E8F4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'This task has no unfinished dates between its recurrence anchor '
                '(${formatDate(options.recurrenceAnchorDate)}) and the current UTC business date '
                '(${formatDate(options.businessDate)}).',
              ),
            ),
          ],
          const SizedBox(height: 14),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Completion details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Private completion note',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                if (widget.task.shareWithFriends) ...<Widget>[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _captionController,
                    maxLines: 3,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      labelText: 'Caption shared with friends',
                      prefixIcon: Icon(Icons.dynamic_feed_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ProofSection(
            proof: _proof,
            proofRequired: widget.task.requiresProofImage,
            enabled: !_saving,
            onCreateOrEdit: _openProofComposer,
            onRemove: _proof == null
                ? null
                : () => setState(() {
                      _proof = null;
                      _error = null;
                    }),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving || !hasAllowedDate ? null : _complete,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Mark completed'),
          ),
        ],
      ),
    );
  }

  static bool _isSameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

final class _TaskHeader extends StatelessWidget {
  const _TaskHeader({required this.task});

  final TaskDetail task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _completionBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            task.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            '${task.categoryName} • ${task.recurrenceName}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B626D),
                ),
          ),
        ],
      ),
    );
  }
}

final class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _completionBorder),
      ),
      child: child,
    );
  }
}

final class _ProofSection extends StatelessWidget {
  const _ProofSection({
    required this.proof,
    required this.proofRequired,
    required this.enabled,
    required this.onCreateOrEdit,
    required this.onRemove,
  });

  final ProofComposition? proof;
  final bool proofRequired;
  final bool enabled;
  final VoidCallback onCreateOrEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final ProofComposition? value = proof;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Photo proof',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: proofRequired
                      ? const Color(0xFFF2E4F7)
                      : const Color(0xFFF2F0F2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  proofRequired ? 'Required' : 'Optional',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value == null
                ? 'Choose a layout, add one to four photos, and edit them before completing the task.'
                : '${ProofLayoutCodes.label(value.layoutCode)} • ${value.photos.length} photo(s)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          if (value == null)
            InkWell(
              onTap: enabled ? onCreateOrEdit : null,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: _completionOrange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: <Widget>[
                    const Positioned(
                      left: 28,
                      top: 26,
                      child: SizedBox(
                        width: 58,
                        height: 108,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _completionPurple,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 106,
                      right: 18,
                      top: 38,
                      bottom: 38,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Create photo proof',
                            style: TextStyle(
                              color: Color(0xFF3E2830),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Choose layout and photos',
                            style: TextStyle(
                              color: const Color(0xFF3E2830)
                                  .withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      right: 18,
                      top: 66,
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: Color(0xFF3E2830),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.memory(
                  value.coverBytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled ? onCreateOrEdit : null,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit proof'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  onPressed: enabled ? onRemove : null,
                  tooltip: 'Remove photo proof',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
