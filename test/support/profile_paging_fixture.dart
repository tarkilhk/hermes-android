import 'profile_browser_fixture.dart';

class ProfilePagingFixture extends ProfileBrowserFixture {
  int count = 125;
  bool prepend = false;

  @override
  List<Map<String, dynamic>> projects(String profile) => [
    {
      'id': 'shared-project',
      'label': '$profile project',
      'path': '/$profile',
      'lastActive': now,
    },
    {
      'id': 'other-project',
      'label': '$profile other project',
      'path': '/$profile/other',
      'lastActive': now - 1,
    },
  ];

  @override
  List<Map<String, dynamic>> sessions(String profile) => [
    if (prepend)
      {
        'id': 'inserted',
        'title': '$profile inserted',
        'profile': profile,
        'last_active': now + 1,
      },
    for (var i = 0; i < count; i++)
      {
        'id': 'chat-$i',
        'title': '$profile chat $i',
        'profile': profile,
        'last_active': now - i * 60,
        'pinned': i == 3 || i == 120,
      },
  ];

  @override
  List<Map<String, dynamic>> projectSessions(String profile, String id) =>
      id == 'other-project'
      ? [
          {
            'id': 'other-only',
            'title': '$profile other only',
            'profile': profile,
            'last_active': now,
            'cwd': '/not-a-membership-filter',
          },
        ]
      : [
          for (final row in sessions(profile))
            Map<String, dynamic>.from(row)..remove('pinned'),
        ];
}
