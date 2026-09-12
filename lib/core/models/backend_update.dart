enum BackendUpdatePhase {
  idle,
  ready,
  starting,
  running,
  succeeded,
  partial,
  refused,
  failed,
  unknown,
}

class BackendUpdateCheck {
  final String? currentVersion;
  final String? installMethod;
  final int? behind;
  final bool? updateAvailable;
  final bool? canApply;

  const BackendUpdateCheck({
    required this.currentVersion,
    required this.installMethod,
    required this.behind,
    required this.updateAvailable,
    required this.canApply,
  });

  factory BackendUpdateCheck.fromJson(Map<String, dynamic> value) {
    String? text(String key) {
      final raw = value[key];
      return raw is String && raw.trim().isNotEmpty ? raw.trim() : null;
    }

    final rawBehind = value['behind'];
    return BackendUpdateCheck(
      currentVersion: text('current_version'),
      installMethod: text('install_method'),
      behind: rawBehind is num && rawBehind.isFinite && rawBehind >= 0
          ? rawBehind.toInt()
          : null,
      updateAvailable: value['update_available'] is bool
          ? value['update_available'] as bool
          : null,
      canApply: value['can_apply'] is bool ? value['can_apply'] as bool : null,
    );
  }

  bool get canStart => canApply == true && updateAvailable == true;
}

class BackendUpdateReceipt {
  final String outcome;
  final int pid;
  final String finishedAt;

  const BackendUpdateReceipt({
    required this.outcome,
    required this.pid,
    required this.finishedAt,
  });

  static BackendUpdateReceipt? fromJson(dynamic value) {
    if (value is! Map ||
        value['outcome'] is! String ||
        value['pid'] is! int ||
        value['finished_at'] is! String) {
      return null;
    }
    final outcome = (value['outcome'] as String).trim();
    final finishedAt = (value['finished_at'] as String).trim();
    final pid = value['pid'] as int;
    return outcome.isEmpty || pid <= 0 || DateTime.tryParse(finishedAt) == null
        ? null
        : BackendUpdateReceipt(
            outcome: outcome,
            pid: pid,
            finishedAt: finishedAt,
          );
  }
}

class BackendUpdateStatus {
  final bool running;
  final int? pid;
  final int? exitCode;
  final String? actionId;
  final List<String> lines;

  const BackendUpdateStatus({
    required this.running,
    required this.pid,
    required this.exitCode,
    required this.actionId,
    required this.lines,
  });

  static BackendUpdateStatus? fromJson(Map<String, dynamic> value) {
    final rawId = value['action_id'];
    final rawLines = value['lines'];
    if (value['running'] is! bool ||
        rawId != null && (rawId is! String || rawId.trim().isEmpty) ||
        rawLines is! List ||
        !rawLines.every((line) => line is String)) {
      return null;
    }
    int? integer(String key) {
      final raw = value[key];
      return raw is int ? raw : null;
    }

    final actionId = rawId as String?;
    final lines = rawLines
        .cast<String>()
        .map((line) => line.replaceAll('\u0000', ''))
        .where((line) => line.trim().isNotEmpty)
        .take(200)
        .map((line) => line.length <= 1000 ? line : line.substring(0, 1000))
        .toList(growable: false);
    return BackendUpdateStatus(
      running: value['running'] as bool,
      pid: integer('pid'),
      exitCode: integer('exit_code'),
      actionId: actionId,
      lines: lines,
    );
  }
}
