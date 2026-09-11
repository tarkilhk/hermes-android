import 'hermes_profile.dart';

enum ProfileLiveActivityState { running, needsInput }

class ProfileLiveActivity {
  final WorkspaceScope workspace;
  final String runtimeId;
  final String sessionId;
  final String title;
  final double lastActive;
  final ProfileLiveActivityState state;

  const ProfileLiveActivity({
    required this.workspace,
    required this.runtimeId,
    required this.sessionId,
    required this.title,
    required this.lastActive,
    required this.state,
  });
}
