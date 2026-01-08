import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final user = state is AuthAuthenticated ? state.user : null;
            
            return ListView(
              children: [
                // Профиль
                ListTile(
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? const Icon(Icons.person, color: Colors.white, size: 32)
                        : null,
                  ),
                  title: Text(
                    user?.name ?? 'Мой профиль',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: Text(
                    _formatPhone(user?.phone ?? ''),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
                
                const Divider(height: 32),
                
                // Уведомления
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: Colors.red),
                  ),
                  title: const Text('Уведомления'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showNotificationsSettings(context);
                  },
                ),
                
                const Divider(height: 32),
                
                // Выйти
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.logout, color: Colors.red),
                  ),
                  title: const Text('Выйти', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    _showLogoutDialog(context);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatPhone(String phone) {
    if (phone.isEmpty) return '';
    // Маскируем часть номера для приватности
    if (phone.length > 6) {
      return '${phone.substring(0, 4)} ••• •• ${phone.substring(phone.length - 2)}';
    }
    return phone;
  }

  void _showNotificationsSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Уведомления',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Сообщения'),
              subtitle: const Text('Уведомления о новых сообщениях'),
              value: true,
              onChanged: (value) {
                // TODO: Save setting
              },
            ),
            SwitchListTile(
              title: const Text('Звонки'),
              subtitle: const Text('Уведомления о входящих звонках'),
              value: true,
              onChanged: (value) {
                // TODO: Save setting
              },
            ),
            SwitchListTile(
              title: const Text('Звук'),
              subtitle: const Text('Звуковые уведомления'),
              value: true,
              onChanged: (value) {
                // TODO: Save setting
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
