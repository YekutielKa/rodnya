import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Контакты'),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
      ),
      body: ListView.builder(
        itemCount: 15,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text('${String.fromCharCode(65 + index)}', style: const TextStyle(color: AppColors.primary)),
            ),
            title: Text('Контакт ${index + 1}'),
            subtitle: Text(index % 2 == 0 ? 'онлайн' : 'был(а) недавно', style: TextStyle(color: index % 2 == 0 ? AppColors.success : AppColors.grey400)),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.person_add)),
    );
  }
}
