import 'dart:async';
import 'package:flutter/material.dart';
import '../services/profile_workspace_controller.dart';
import '../widgets/profile_tool_activity.dart';

/// Reversed layout opens at the newest row. Older pages grow at the far end;
/// a visible durable row anchors the viewport when streaming changes the tail.
class ProfileTranscript extends StatefulWidget {
  final ProfileChat chat;
  final ProfileWorkspaceController controller;
  final Widget Function(Map<String, dynamic>) messageBuilder;
  final List<Widget> tail;
  const ProfileTranscript({
    super.key,
    required this.chat,
    required this.controller,
    required this.messageBuilder,
    required this.tail,
  });
  @override
  State<ProfileTranscript> createState() => _ProfileTranscriptState();
}

class _ProfileTranscriptState extends State<ProfileTranscript> {
  late final _scroll = ScrollController(
    initialScrollOffset: widget.chat.historyScrollOffset,
  );
  final _viewport = GlobalKey();
  final _rows = <Object, GlobalKey>{};
  int _layoutGeneration = 0;
  int _gestureGeneration = 0;
  bool _jumping = false;
  bool _hasNewContent = false;
  Object? _newestId;
  late String _streaming;
  String? _segment;
  late final _jumpLabel = ValueNotifier<String?>(
    widget.chat.historyScrollOffset > 48 ? 'Latest' : null,
  );

  @override
  void initState() {
    super.initState();
    _newestId = widget.chat.messages.lastOrNull?['id'];
    _streaming = widget.chat.streaming;
    _segment = widget.chat.historySessionId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateJump());
  }

  void _updateJump() {
    if (!mounted || !_scroll.hasClients) return;
    final distance = _scroll.offset;
    if (distance <= 24) _hasNewContent = false;
    final attention =
        widget.chat.approval != null || widget.chat.pendingQuestion != null;
    _jumpLabel.value =
        distance <= 24 || (distance <= 48 && !_hasNewContent && !attention)
        ? null
        : attention
        ? 'Input needed'
        : _hasNewContent
        ? 'New activity'
        : 'Latest';
  }

  Future<void> _latest() async {
    _jumping = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    _jumping = false;
    _updateJump();
  }

  @override
  void didUpdateWidget(covariant ProfileTranscript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_scroll.hasClients) return;
    final atBottom = _scroll.offset <= 24 || _jumping;
    final newest = widget.chat.messages.lastOrNull?['id'];
    final segmentChanged = _segment != widget.chat.historySessionId;
    if (!atBottom &&
        !segmentChanged &&
        ((_newestId != null && newest != null && newest != _newestId) ||
            (widget.chat.streaming.isNotEmpty &&
                widget.chat.streaming != _streaming))) {
      _hasNewContent = true;
    }
    _newestId = newest;
    _streaming = widget.chat.streaming;
    _segment = widget.chat.historySessionId;
    GlobalKey? anchor;
    double? top;
    final viewport = _viewport.currentContext?.findRenderObject();
    if (!atBottom && viewport is RenderBox) {
      final start = viewport.localToGlobal(Offset.zero).dy;
      final end = start + viewport.size.height;
      for (final key in _rows.values) {
        final box = key.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) continue;
        final y = box.localToGlobal(Offset.zero).dy;
        if (y < end &&
            y + box.size.height > start &&
            (top == null || y < top)) {
          anchor = key;
          top = y;
        }
      }
    }
    final generation = ++_layoutGeneration;
    final gesture = _gestureGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scroll.hasClients ||
          generation != _layoutGeneration ||
          gesture != _gestureGeneration) {
        return;
      }
      if (atBottom) {
        _scroll.jumpTo(0);
      } else {
        final box = anchor?.currentContext?.findRenderObject();
        if (box is RenderBox && box.hasSize && top != null) {
          final delta = box.localToGlobal(Offset.zero).dy - top;
          if (delta.abs() > 0.5) {
            _scroll.jumpTo(
              (_scroll.offset - delta).clamp(
                0.0,
                _scroll.position.maxScrollExtent,
              ),
            );
          }
        }
      }
      widget.chat.historyScrollOffset = _scroll.offset;
      _updateJump();
    });
  }

  @override
  void dispose() {
    if (_scroll.hasClients) widget.chat.historyScrollOffset = _scroll.offset;
    _scroll.dispose();
    _jumpLabel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final tail = widget.tail.reversed.toList();
    final rows = groupTranscriptSections(chat.messages).reversed.toList();
    final activeIds = chat.messages
        .where((r) => r['id'] != null)
        .map((r) => r['id'])
        .toSet();
    _rows.removeWhere((id, _) => !activeIds.contains(id));
    // A sliver needs an index lookup to retain mounted message/expansion state
    // when a new tail shifts every existing row's index.
    final keys = <Key>[];
    final usedKeys = <Key>{};
    for (final section in rows) {
      final group = section.messages.toList();
      final existing = group.reversed
          .map((row) => _rows[row['id']])
          .whereType<GlobalKey>()
          .where((key) => !usedKeys.contains(key))
          .firstOrNull;
      final id = group.last['id'];
      final key = existing ?? GlobalKey();
      if (id != null) _rows[id] = key;
      keys.add(key);
      usedKeys.add(key);
    }
    final indices = <Key, int>{
      for (var i = 0; i < keys.length; i++) keys[i]: tail.length + i,
      const ValueKey('history-edge'): tail.length + rows.length,
    };
    return Stack(
      key: _viewport,
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (event) {
            if (event.depth != 0) return false;
            if (event is ScrollStartNotification && event.dragDetails != null ||
                event is ScrollUpdateNotification &&
                    event.dragDetails != null) {
              _gestureGeneration++;
              _jumping = false;
            }
            widget.chat.historyScrollOffset = event.metrics.pixels;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateJump();
            });
            if ((event is ScrollUpdateNotification ||
                    event is ScrollEndNotification) &&
                event.metrics.extentAfter < 180 &&
                event.metrics.pixels > 0 &&
                !chat.historyLoading &&
                chat.historyError == null) {
              unawaited(widget.controller.loadOlderMessages(chat));
            }
            return false;
          },
          child: ListView.builder(
            key: const ValueKey('profile-transcript'),
            controller: _scroll,
            reverse: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            findChildIndexCallback: (key) => indices[key],
            itemCount: tail.length + rows.length + 1,
            itemBuilder: (_, index) {
              if (index < tail.length) return tail[index];
              final rowIndex = index - tail.length;
              if (rowIndex < rows.length) {
                final section = rows[rowIndex];
                final row = section.messages.last;
                return KeyedSubtree(
                  key: keys[rowIndex],
                  child: section.isTool
                      ? ProfileToolActivitySection(groups: section.groups)
                      : widget.messageBuilder(row),
                );
              }
              return KeyedSubtree(
                key: const ValueKey('history-edge'),
                child: _historyEdge(chat),
              );
            },
          ),
        ),
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<String?>(
            valueListenable: _jumpLabel,
            builder: (_, label, _) => label != null
                ? Center(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('jump-to-latest'),
                      onPressed: _latest,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 36),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      icon: Icon(
                        label == 'Input needed'
                            ? Icons.question_answer_outlined
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                      label: Text(label),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _historyEdge(ProfileChat chat) {
    if (chat.historyLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading history…'),
          ],
        ),
      );
    }
    if (chat.historyError != null) {
      return Column(
        children: [
          Text(chat.historyError!),
          TextButton(
            onPressed: () => widget.controller.refreshHistory(chat),
            child: const Text('Refresh history'),
          ),
          if (chat.nextHistoryOffset != null)
            TextButton(
              onPressed: () => widget.controller.loadOlderMessages(chat),
              child: const Text('Retry older messages'),
            ),
        ],
      );
    }
    return chat.nextHistoryOffset == null
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              chat.messages.isEmpty
                  ? 'Start a conversation'
                  : 'Start of loaded history',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        : TextButton(
            onPressed: () => widget.controller.loadOlderMessages(chat),
            child: const Text('Load older messages'),
          );
  }
}
