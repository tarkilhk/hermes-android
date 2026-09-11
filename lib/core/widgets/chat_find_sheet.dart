import 'dart:async';

import 'package:flutter/material.dart';

typedef ChatHistoryLoader = Future<List<Map<String, dynamic>>> Function();

Future<void> showChatFindSheet(
  BuildContext context, {
  required ChatHistoryLoader loadHistory,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => ChatFindSheet(loadHistory: loadHistory),
);

class ChatFindSheet extends StatefulWidget {
  final ChatHistoryLoader loadHistory;
  const ChatFindSheet({super.key, required this.loadHistory});

  @override
  State<ChatFindSheet> createState() => _ChatFindSheetState();
}

class _ChatFindSheetState extends State<ChatFindSheet> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _history = const [];
  bool _loading = true;
  String? _error;
  final _expanded = <int>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final history = await widget.loadHistory();
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _allMatches {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _history
        .where((row) => _rowText(row).toLowerCase().contains(query))
        .toList(growable: false);
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _load();
  }

  static String _rowText(Map<String, dynamic> row) {
    final content = row['content'] ?? row['text'] ?? row['message'];
    return content is String ? content : content?.toString() ?? '';
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allMatches = _allMatches;
    final matches = allMatches.take(100).toList();
    return Material(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    onChanged: (_) => setState(_expanded.clear),
                    decoration: const InputDecoration(
                      labelText: 'Find in chat',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _retry,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _query.text.trim().isEmpty
                      ? const Center(child: Text('Type to search this chat.'))
                      : matches.isEmpty
                      ? const Center(child: Text('No matching messages.'))
                      : ListView.builder(
                          itemCount: matches.length,
                          itemBuilder: (_, index) {
                            final row = matches[index];
                            final role = row['role']?.toString() ?? 'message';
                            final expanded = _expanded.contains(index);
                            return ExpansionTile(
                              key: ValueKey((_query.text, row['id'] ?? index)),
                              initiallyExpanded: expanded,
                              onExpansionChanged: (open) => setState(() {
                                if (open) {
                                  _expanded.add(index);
                                } else {
                                  _expanded.remove(index);
                                }
                              }),
                              leading: Icon(
                                role == 'user'
                                    ? Icons.person_outline
                                    : Icons.smart_toy_outlined,
                              ),
                              title: expanded
                                  ? SelectableText(_rowText(row))
                                  : Text(
                                      _rowText(row),
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              subtitle: Text(role),
                            );
                          },
                        ),
                ),
                if (!_loading && _query.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      allMatches.length > matches.length
                          ? 'Showing first ${matches.length} of ${allMatches.length} matching messages'
                          : '${matches.length} matching messages',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
