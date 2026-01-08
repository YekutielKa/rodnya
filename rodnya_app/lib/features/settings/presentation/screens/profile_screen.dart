import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                const CircleAvatar(radius: 50, backgroundColor: AppColors.primary, child: Icon(Icons.person, size: 50, color: AppColors.white)),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, size: 18, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _ProfileField(label: 'Имя', value: 'Имя Пользователя', onTap: () {}),
          _ProfileField(label: 'Телефон', value: '+7 XXX XXX XX XX', onTap: null),
          _ProfileField(label: 'Статус', value: 'Привет! Я использую Rodnya', onTap: () {}),
          _ProfileField(label: 'О себе', value: 'Добавить информацию о себе', onTap: () {}),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ProfileField({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primary)),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      trailing: onTap != null ? const Icon(Icons.edit, size: 20) : null,
      onTap: onTap,
    );
  }
}
