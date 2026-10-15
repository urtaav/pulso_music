import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme.dart';

enum _Access { checking, granted, denied, blocked }

/// Shows [child] only once the app can read the phone's music.
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key, required this.child});

  final Widget child;

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  _Access _access = _Access.checking;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Si el usuario lo concede desde Ajustes del sistema, se detecta al volver.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_access != _Access.granted) _check(request: false);
      },
    );
    _check(request: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check({required bool request}) async {
    // Android 13+ usa READ_MEDIA_AUDIO (Permission.audio); antes, almacenamiento.
    // Se piden ambos y basta con que uno aplique.
    final permissions = [Permission.audio, Permission.storage];
    final statuses = request
        ? (await permissions.request()).values
        : await Future.wait(permissions.map((p) => p.status));
    if (!mounted) return;
    setState(() {
      if (statuses.any((s) => s.isGranted || s.isLimited)) {
        _access = _Access.granted;
      } else if (statuses.any((s) => s.isPermanentlyDenied)) {
        _access = _Access.blocked;
      } else {
        _access = _Access.denied;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_access) {
      _Access.granted => widget.child,
      _Access.checking => const Scaffold(body: SizedBox.shrink()),
      _ => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Tu música,\naquí.', style: TextStyles.display),
                const SizedBox(height: 16),
                const Text(
                  'pulso necesita permiso para leer los archivos de audio de tu '
                  'teléfono. No sube nada a internet: todo se queda en tu equipo.',
                  style: TextStyles.body,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _access == _Access.blocked
                        ? openAppSettings
                        : () => _check(request: true),
                    child: Text(
                      _access == _Access.blocked
                          ? 'Abrir ajustes'
                          : 'Dar acceso',
                    ),
                  ),
                ),
                if (_access == _Access.blocked)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Ajustes › Permisos › Música y audio › Permitir',
                      style: TextStyles.caption,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    };
  }
}
