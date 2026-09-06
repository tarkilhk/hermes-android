import 'package:flutter/material.dart';
import 'hermes_theme.dart';

/// Workspace art direction, isolated from connection setup and legacy screens.
enum WorkspaceAccent {
  mint('Mint', Color(0xFFB5F4D7), Color(0xFF006C50)),
  iris('Iris', Color(0xFFD0BFFF), Color(0xFF6341A7)),
  glacier('Glacier', Color(0xFFA8D9FF), Color(0xFF14638E)),
  coral('Coral', Color(0xFFFFC3AE), Color(0xFF984728)),
  gold('Gold', Color(0xFFF0D589), Color(0xFF745A0A));

  const WorkspaceAccent(this.label, this.dark, this.light);
  final String label;
  final Color dark;
  final Color light;
  static const preferenceKey = 'workspace_accent_v1';
  static WorkspaceAccent fromName(String? name) =>
      values.where((accent) => accent.name == name).firstOrNull ?? mint;
}

ThemeData profileWorkspaceTheme(
  ThemeData base, {
  WorkspaceAccent accent = WorkspaceAccent.mint,
}) {
  final dark = base.brightness == Brightness.dark;
  final ink = dark ? const Color(0xFFF1F4FA) : const Color(0xFF152133);
  final canvas = dark ? const Color(0xFF0C1420) : const Color(0xFFF3F6FA);
  final panel = dark ? const Color(0xFF172335) : Colors.white;
  final muted = dark ? const Color(0xFFADBBCF) : const Color(0xFF516176);
  final line = dark ? const Color(0xFF304057) : const Color(0xFFD5DDE8);
  final mint = dark ? accent.dark : accent.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent.light,
        brightness: base.brightness,
      ).copyWith(
        surface: canvas,
        surfaceContainer: panel,
        surfaceContainerLow: panel,
        surfaceContainerHigh: panel,
        onSurface: ink,
        onSurfaceVariant: muted,
        primary: mint,
        onPrimary: dark ? const Color(0xFF142332) : Colors.white,
        outlineVariant: line,
      );
  final tokens = HermesTokens.forBrightness(base.brightness).copyWith(
    surface: canvas,
    raised: panel,
    onSurface: ink,
    muted: muted,
    border: line,
    accent: mint,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: canvas,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: line),
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(backgroundColor: panel),
    extensions: [tokens],
  );
}

/// Decorative project accents are identities, never execution status.
Color projectAccent(BuildContext context, String id) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final palette = dark
      ? const [Color(0xFFBEB4FF), Color(0xFFA8D9FF), Color(0xFFFFC3A0)]
      : const [Color(0xFF6752A6), Color(0xFF23638D), Color(0xFF984A22)];
  final hash = id.codeUnits.fold(0, (a, b) => a * 31 + b);
  return palette[hash.abs() % palette.length];
}
