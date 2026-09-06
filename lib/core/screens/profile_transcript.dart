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
  late final _showJump = ValueNotifier(widget.chat.historyScrollOffset > 180);

  @override
  void didUpdateWidget(covariant ProfileTranscript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_scroll.hasClients) return;
    final atBottom = _scroll.offset < 24;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || generation != _layoutGeneration) {
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
    });
  }

  @override
  void dispose() {
    if (_scroll.hasClients) widget.chat.historyScrollOffset = _scroll.offset;
    _scroll.dispose();
    _showJump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final tail = widget.tail.reversed.toList();
    final rows = groupTranscriptRows(chat.messages).reversed.toList();
    final activeIds = chat.messages
        .where((r) => r['id'] != null)
        .map((r) => r['id'])
        .toSet();
    _rows.removeWhere((id, _) => !activeIds.contains(id));
    return Stack(
      key: _viewport,
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (event) {
            if (event.depth != 0) return false;
            widget.chat.historyScrollOffset = event.metrics.pixels;
            final showJump = event.metrics.pixels > 180;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showJump.value = showJump;
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
            padding: const EdgeInsets.all(16),
            itemCount: tail.length + rows.length + 1,
            itemBuilder: (_, index) {
              if (index < tail.length) return tail[index];
              final rowIndex = index - tail.length;
              if (rowIndex < rows.length) {
                final group = rows[rowIndex];
                final row = group.last;
                return KeyedSubtree(
                  key: row['id'] == null
                      ? null
                      : _rows.putIfAbsent(row['id'], () => GlobalKey()),
                  child: row['role'] == 'tool'
                      ? ProfileToolActivity(messages: group)
                      : widget.messageBuilder(row),
                );
              }
              if (chat.historyLoading) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
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
                        onPressed: () =>
                            widget.controller.loadOlderMessages(chat),
                        child: const Text('Retry older messages'),
                      ),
                  ],
                );
              }
              return chat.nextHistoryOffset == null
                  ? const SizedBox.shrink()
                  : TextButton(
                      onPressed: () =>
                          widget.controller.loadOlderMessages(chat),
                      child: const Text('Load older messages'),
                    );
            },
          ),
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: _showJump,
            builder: (_, show, _) => show
                ? Center(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('jump-to-latest'),
                      onPressed: () => _scroll.animateTo(
                        0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      ),
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      label: const Text('Latest'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
