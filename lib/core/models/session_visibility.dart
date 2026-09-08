/// Hermes source labels for scheduled and internal runs. Unknown sources remain
/// visible in Chats; a source label cannot prove that a person started a session.
enum SessionVisibility {
  chats('Chats'),
  automated('Automated'),
  all('All');

  const SessionVisibility(this.label);
  final String label;

  static const automatedSources = {'cron', 'tool', 'subagent', 'kanban'};

  Map<String, String> get queryParameters => switch (this) {
    chats => {'exclude_sources': automatedSources.join(',')},
    automated => {'sources': automatedSources.join(',')},
    all => const {},
  };

  bool includes(String? source) => switch (this) {
    chats => !automatedSources.contains(source),
    automated => automatedSources.contains(source),
    all => true,
  };

  static SessionVisibility fromStored(String? value) =>
      values.where((v) => v.name == value).firstOrNull ?? chats;
}
