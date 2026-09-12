import 'package:url_launcher/url_launcher.dart';

Uri? externalWebLink(String href) {
  final uri = Uri.tryParse(href);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

/// Uses the installed browser's preview, without Hermes request credentials.
Future<bool> openWebPreview(Uri uri) async {
  if (externalWebLink(uri.toString()) == null) return false;
  try {
    if (await supportsLaunchMode(LaunchMode.inAppBrowserView) &&
        await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
          browserConfiguration: const BrowserConfiguration(showTitle: true),
        )) {
      return true;
    }
  } catch (_) {
    // A missing or unavailable browser preview can still open externally.
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
