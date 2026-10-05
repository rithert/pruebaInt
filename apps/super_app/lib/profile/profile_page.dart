import 'package:accounts/accounts.dart';
import 'package:auth/auth.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pestaña Perfil: datos del cliente, privacidad, soporte y cierre de
/// sesión. Vive en el shell porque combina varios dominios (auth, cuentas).
class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.onOpenDiagnostics, super.key});

  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.select((SessionCubit c) => c.state.user);
    final hidden = context.watch<BalanceVisibilityCubit>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      child: Text(
                        _initials(user.fullName),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: theme.textTheme.titleLarge),
                        Text(
                          user.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          const SectionHeader('Privacidad'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              title: const Text('Ocultar saldos'),
              subtitle: const Text(
                'Los montos de tus cuentas se reemplazan por •••• en toda la '
                'app. Útil en lugares públicos.',
              ),
              value: hidden,
              onChanged: (_) => context.read<BalanceVisibilityCubit>().toggle(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('Soporte'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('Diagnóstico de conexión'),
              subtitle: const Text('Verifica el estado de los servicios.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenDiagnostics,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
              minimumSize: const Size.fromHeight(AppSpacing.minTouchTarget),
            ),
            onPressed: context.read<SessionCubit>().logout,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  static String _initials(String fullName) => fullName
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}
