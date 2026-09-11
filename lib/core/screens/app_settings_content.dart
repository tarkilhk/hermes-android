import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/profile_workspace_theme.dart';
import '../services/turn_notification_service.dart';
import '../widgets/text_size_settings_card.dart';

/// Existing device preferences, shared by connected and disconnected navigation.
class AppSettingsContent extends StatefulWidget {
  const AppSettingsContent({
    super.key,
    required this.preferences,
    required this.onChanged,
    this.enableNotifications,
  });

  final SharedPreferences preferences;
  final VoidCallback onChanged;
  final Future<void> Function()? enableNotifications;

  @override
  State<AppSettingsContent> createState() => _AppSettingsContentState();
}

class _AppSettingsContentState extends State<AppSettingsContent> {
  bool _requesting = false;

  Future<void> _save(String key, Object value) async {
    try {
      final saved = value is bool
          ? await widget.preferences.setBool(key, value)
          : await widget.preferences.setString(key, value as String);
      if (!saved) {
        throw StateError('Could not save the setting');
      }
      if (!mounted) return;
      setState(() {});
      widget.onChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the setting. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _notifications() async {
    setState(() => _requesting = true);
    try {
      await widget.enableNotifications!();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test alert sent. Check your notifications.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'Could not send the test notification.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = WorkspaceAccent.fromName(
      widget.preferences.getString(WorkspaceAccent.preferenceKey),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text('Appearance and notifications for this device.'),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in ['system', 'light', 'dark'])
                      ChoiceChip(
                        key: ValueKey('theme-$mode'),
                        label: Text(
                          '${mode[0].toUpperCase()}${mode.substring(1)}',
                        ),
                        selected:
                            (widget.preferences.getString('theme_mode') ??
                                'system') ==
                            mode,
                        onSelected: (_) => _save('theme_mode', mode),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Accent color',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final choice in WorkspaceAccent.values)
                      ChoiceChip(
                        key: ValueKey('accent-${choice.name}'),
                        label: Text(choice.label),
                        selected: accent == choice,
                        avatar: CircleAvatar(
                          radius: 9,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? choice.dark
                              : choice.light,
                        ),
                        onSelected: (_) =>
                            _save(WorkspaceAccent.preferenceKey, choice.name),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextSizeSettingsCard(
          preferences: widget.preferences,
          onChanged: (_) => widget.onChanged(),
        ),
        if (widget.enableNotifications != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Completed work'),
                  value:
                      widget.preferences.getBool(completionNotificationsKey) ??
                      true,
                  onChanged: (value) =>
                      _save(completionNotificationsKey, value),
                ),
                SwitchListTile(
                  title: const Text('Needs attention'),
                  subtitle: const Text(
                    'Questions, approvals and failed turns.',
                  ),
                  value:
                      widget.preferences.getBool(attentionNotificationsKey) ??
                      true,
                  onChanged: (value) => _save(attentionNotificationsKey, value),
                ),
                SwitchListTile(
                  title: const Text('Show chat titles in alerts'),
                  subtitle: const Text(
                    'Allow notification previews to include the chat title.',
                  ),
                  value:
                      widget.preferences.getBool(notificationTitlesKey) ??
                      false,
                  onChanged: (value) => _save(notificationTitlesKey, value),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Alerts currently require an active connection to Hermes. Background push is planned.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Enable and test notifications'),
              subtitle: const Text(
                'Request Android permission and send a test alert.',
              ),
              trailing: _requesting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _requesting ? null : _notifications,
            ),
          ),
        ],
      ],
    );
  }
}
