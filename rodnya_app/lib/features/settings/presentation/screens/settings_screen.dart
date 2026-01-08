import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/router.dart';
import '../../../../core/config/theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(radius: 30, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: AppColors.white, size: 30)),
            title: const Text('Мой профиль', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('+7 XXX XXX XX XX'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.profile),
          ),
          const Divider(),
          _SettingsTile(icon: Icons.notifications_outlined, title: 'Уведомления', onTap: () {}),
          _SettingsTile(icon: Icons.lock_outline, title: 'Приватность', onTap: () {}),
          _SettingsTile(icon: Icons.palette_outlined, title: 'Оформление', onTap: () {}),
          _SettingsTile(icon: Icons.language_outlined, title: 'Язык', subtitle: 'Русский', onTap: () {}),
          _SettingsTile(icon: Icons.storage_outlined, title: 'Данные и память', onTap: () {}),
          const Divider(),
          _SettingsTile(icon: Icons.help_outline, title: 'Помощь', onTap: () {}),
          _SettingsTile(icon: Icons.info_outline, title: 'О приложении', onTap: () {}),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Выйти', style: TextStyle(color: AppColors.error)),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Выход'),
                  content: const Text('Вы уверены, что хотите выйти?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                      },
                      child: const Text('Выйти', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.grey600),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
