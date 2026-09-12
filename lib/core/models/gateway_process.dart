enum GatewayProcessStatus { running, exited }

class GatewayProcessActivity {
  static const _maxIdLength = 256;
  static const _maxCommandLength = 200;
  static const _maxCwdLength = 1000;
  static const _maxOutputLength = 4000;

  final String id;
  final String command;
  final String? cwd;
  final String? outputTail;
  final GatewayProcessStatus status;
  final int? exitCode;
  final int? uptimeSeconds;
  final int? pid;
  final bool detached;
  final bool notifyOnComplete;

  const GatewayProcessActivity({
    required this.id,
    required this.command,
    required this.status,
    this.cwd,
    this.outputTail,
    this.exitCode,
    this.uptimeSeconds,
    this.pid,
    this.detached = false,
    this.notifyOnComplete = false,
  });

  bool get isRunning => status == GatewayProcessStatus.running;

  static GatewayProcessActivity? fromJson(Map<String, dynamic> value) {
    final rawId = value['session_id'];
    if (rawId is! String ||
        rawId.trim().isEmpty ||
        rawId.contains('\u0000') ||
        rawId.length > _maxIdLength) {
      return null;
    }
    final status = switch (value['status']) {
      'running' => GatewayProcessStatus.running,
      'exited' => GatewayProcessStatus.exited,
      _ => null,
    };
    if (status == null) {
      return null;
    }
    final rawCommand = value['command'];
    final command = rawCommand is String
        ? _displayText(rawCommand, _maxCommandLength)
        : null;
    return GatewayProcessActivity(
      id: rawId,
      command: command ?? 'Background process',
      cwd: _displayText(value['cwd'], _maxCwdLength),
      outputTail: _output(value['output_tail']),
      status: status,
      exitCode: _integer(value['exit_code']),
      uptimeSeconds: _nonNegativeInteger(value['uptime_seconds']),
      pid: _positiveInteger(value['pid']),
      detached: value['detached'] == true,
      notifyOnComplete: value['notify_on_complete'] == true,
    );
  }

  static String? _displayText(dynamic value, int maxLength) {
    if (value is! String) {
      return null;
    }
    final safe = value
        .replaceAll('\u0000', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (safe.isEmpty) {
      return null;
    }
    return safe.length <= maxLength
        ? safe
        : '${safe.substring(0, maxLength - 1)}…';
  }

  static String? _output(dynamic value) {
    if (value is! String) {
      return null;
    }
    final safe = value.replaceAll('\u0000', '');
    if (safe.trim().isEmpty) {
      return null;
    }
    return safe.length <= _maxOutputLength
        ? safe
        : safe.substring(safe.length - _maxOutputLength);
  }

  static int? _integer(dynamic value) =>
      value is num && value.isFinite ? value.toInt() : null;

  static int? _nonNegativeInteger(dynamic value) {
    final parsed = _integer(value);
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  static int? _positiveInteger(dynamic value) {
    final parsed = _integer(value);
    return parsed != null && parsed > 0 ? parsed : null;
  }
}
