import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

final class ManageHighlightsScreen extends ConsumerStatefulWidget {
  const ManageHighlightsScreen({super.key});

  @override
  ConsumerState<ManageHighlightsScreen> createState() =>
      _ManageHighlightsScreenState();
}

final class _ManageHighlightsScreenState
    extends ConsumerState<ManageHighlightsScreen> {
  static const int _maximumHighlights = 6;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busyPostIds = <String>{};
  List<ProfileHighlightCandidate> _items = <ProfileHighlightCandidate>[];
  Object? _error;
  bool _loading = true;

  int get _highlightedCount => _items
      .where((ProfileHighlightCandidate item) => item.isHighlighted)
      .length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final PagedResult<ProfileHighlightCandidate> page =
          await ref.read(authRepositoryProvider).getHighlightCandidates(
                search: _searchController.text,
                page: 1,
                pageSize: 100,
              );
      if (!mounted) return;
      setState(() {
        // Paged API responses expose an immutable list. Keep a mutable local
        // copy because this screen updates an item's highlighted state after
        // a successful add/remove request.
        _items = List<ProfileHighlightCandidate>.of(page.items);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(ProfileHighlightCandidate item) async {
    if (_busyPostIds.contains(item.postId)) return;
    if (!item.isHighlighted && _highlightedCount >= _maximumHighlights) {
      showMessage(
        context,
        'You can feature at most $_maximumHighlights highlighted posts.',
        error: true,
      );
      return;
    }

    setState(() => _busyPostIds.add(item.postId));
    try {
      if (item.isHighlighted) {
        await ref.read(authRepositoryProvider).removeHighlight(item.postId);
      } else {
        await ref.read(authRepositoryProvider).highlightPost(item.postId);
      }
      if (!mounted) return;
      final int index = _items.indexWhere(
        (ProfileHighlightCandidate candidate) =>
            candidate.postId == item.postId,
      );
      if (index >= 0) {
        setState(() {
          final List<ProfileHighlightCandidate> updatedItems =
              List<ProfileHighlightCandidate>.of(_items);
          updatedItems[index] = item.copyWithHighlighted(!item.isHighlighted);
          _items = updatedItems;
        });
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      if (mounted) setState(() => _busyPostIds.remove(item.postId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Highlighted posts')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Choose up to $_maximumHighlights completed tasks with proof to feature on your profile.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SearchBar(
                  key: const Key('highlight-search'),
                  controller: _searchController,
                  hintText: 'Search completed tasks',
                  leading: const Icon(Icons.search),
                  trailing: <Widget>[
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                        icon: const Icon(Icons.close),
                      ),
                  ],
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _load(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _highlightedCount / _maximumHighlights,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$_highlightedCount/$_maximumHighlights selected',
                      key: const Key('highlight-count'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorView(error: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.photo_library_outlined,
        title: 'No eligible proof posts',
        message:
            'Complete a shared task with a proof image before featuring it on your profile.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        key: const Key('highlight-candidates-grid'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (BuildContext context, int index) {
          final ProfileHighlightCandidate item = _items[index];
          return ProfileHighlightCandidateCard(
            candidate: item,
            isBusy: _busyPostIds.contains(item.postId),
            onTap: () => _toggle(item),
          );
        },
      ),
    );
  }
}

final class ProfileHighlightCandidateCard extends StatelessWidget {
  const ProfileHighlightCandidateCard({
    required this.candidate,
    required this.onTap,
    this.isBusy = false,
    this.thumbnail,
    super.key,
  });

  final ProfileHighlightCandidate candidate;
  final VoidCallback onTap;
  final bool isBusy;
  final Widget? thumbnail;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: candidate.isHighlighted ? 3 : 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color:
              candidate.isHighlighted ? colors.primary : colors.outlineVariant,
          width: candidate.isHighlighted ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: isBusy ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  thumbnail ??
                      ProtectedImage(
                        path: candidate.proofUrl,
                        fit: BoxFit.cover,
                      ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: candidate.isHighlighted
                            ? colors.primary
                            : Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: isBusy
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              candidate.isHighlighted ? Icons.check : Icons.add,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    candidate.taskTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${candidate.categoryName} • ${formatDate(candidate.completedAtUtc)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.outline,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
