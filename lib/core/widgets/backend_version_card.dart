import 'package:flutter/material.dart';

import '../services/profile_gateway.dart';

/// Read-only backend identity and update information for one captured scope.
/// The parent supplies the already-scoped gateway operation; this widget never
/// constructs a connection or executes an update command.
class BackendVersionCard extends StatefulWidget {
  final ProfileGateway gateway;

  const BackendVersionCard({super.key, required this.gateway});

  @override
  State<BackendVersionCard> createState() => _BackendVersionCardState();
}

class _BackendVersionCardState extends State<BackendVersionCard> {
  Map<String, dynamic>? _info;
  Object? _error;
  bool _checking = false;
  int _requestGeneration = 0;

  @override
  void didUpdateWidget(covariant BackendVersionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.gateway, widget.gateway)) {
      _requestGeneration++;
      setState(() {
        _info = null;
        _error = null;
        _checking = false;
      });
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    final gateway = widget.gateway;
    final generation = ++_requestGeneration;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final info = await gateway.read('hermes/update/check', {'force': 'true'});
      if (!mounted ||
          generation != _requestGeneration ||
          !identical(widget.gateway, gateway)) {
        return;
      }
      setState(() => _info = info);
    } catch (error) {
      if (!mounted ||
          generation != _requestGeneration ||
          !identical(widget.gateway, gateway)) {
        return;
      }
      setState(() => _error = error);
    } finally {
      if (mounted &&
          generation == _requestGeneration &&
          identical(widget.gateway, gateway)) {
        setState(() => _checking = false);
      }
    }
  }

  String _status(Map<String, dynamic>? info) {
    if (info == null) return 'Update status unavailable.';
    final advertised = info['update_available'];
    final behind = info['behind'];
    final validBehind = behind is num && behind.isFinite && behind >= 0;
    if (advertised is! bool || !validBehind && advertised == false) {
      return 'Update status unavailable.';
    }
    if (advertised) {
      if (validBehind && behind > 0) {
        return 'Update available · ${behind.toInt()} commits behind';
      }
      return 'Update available';
    }
    return validBehind && behind == 0
        ? 'Up to date'
        : 'Update status unavailable.';
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final rawVersion = info?['current_version'];
    final rawMethod = info?['install_method'];
    final version = rawVersion is String ? rawVersion.trim() : '';
    final method = rawMethod is String ? rawMethod.trim() : '';
    final status = _error == null
        ? _status(info)
        : 'Could not check for updates.';
    final guidance = info?['can_apply'] == false
        ? 'Updates must be applied from the server host.'
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('Backend version')),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _checking ? null : _check,
                child: Text(_checking ? 'Checking…' : 'Check for updates'),
              ),
            ),
            Text(version.isEmpty ? 'Current version unavailable' : version),
            if (method.isNotEmpty) Text('Install method: $method'),
            const SizedBox(height: 4),
            Text(status),
            if (guidance != null) Text(guidance),
            if (_error != null)
              const Text('Try again to request fresh server information.'),
          ],
        ),
      ),
    );
  }
}
