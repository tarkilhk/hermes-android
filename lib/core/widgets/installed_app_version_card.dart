import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Displays the installed application's identity from Android package metadata.
class InstalledAppVersionCard extends StatefulWidget {
  const InstalledAppVersionCard({super.key});

  @override
  State<InstalledAppVersionCard> createState() =>
      _InstalledAppVersionCardState();
}

class _InstalledAppVersionCardState extends State<InstalledAppVersionCard> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (snapshot.hasError ||
            (snapshot.connectionState == ConnectionState.done &&
                info == null)) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Android app version'),
              subtitle: Text('Version information is unavailable.'),
            ),
          );
        }
        if (info == null) {
          return const Card(
            child: ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Android app version'),
              subtitle: Text('Loading version information…'),
            ),
          );
        }
        final version = info.buildNumber.trim().isEmpty
            ? info.version
            : '${info.version} (${info.buildNumber})';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.phone_android),
            title: Text(
              info.appName.trim().isEmpty ? 'Android app' : info.appName,
            ),
            subtitle: Text('$version\n${info.packageName}'),
          ),
        );
      },
    );
  }
}
