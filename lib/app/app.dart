import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../ui/shell/app_shell.dart';
import '../ui/shell/permission_gate.dart';
import '../ui/visualizer/edge_visualizer.dart';
import 'theme.dart';

class PulsoApp extends ConsumerWidget {
  const PulsoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Color(ref.watch(settingsProvider.select((s) => s.accent)));
    return MaterialApp(
      title: 'pulso',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(accent),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const PermissionGate(child: AppShell()),
      // El visualizador va sobre todas las pantallas, pegado al borde físico.
      builder: (context, child) => Stack(
        children: [
          ?child,
          const Positioned.fill(child: EdgeVisualizerOverlay()),
        ],
      ),
    );
  }
}
