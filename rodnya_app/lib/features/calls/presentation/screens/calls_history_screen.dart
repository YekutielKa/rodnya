import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';

class CallsHistoryScreen extends StatelessWidget {
  const CallsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Звонки')),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          final isMissed = index % 3 == 0;
          final isVideo = index % 2 == 0;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Text('U${index + 1}', style: const TextStyle(color: AppColors.primary)),
            ),
            title: Text('User ${index + 1}'),
            subtitle: Row(
              children: [
                Icon(isMissed ? Icons.call_missed : Icons.call_made, size: 16, color: isMissed ? AppColors.error : AppColors.success),
                const SizedBox(width: 4),
                Text(isMissed ? 'Пропущенный' : 'Исходящий'),
                const SizedBox(width: 8),
                Text('${index + 1} мин', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            trailing: IconButton(
              icon: Icon(isVideo ? Icons.videocam : Icons.call, color: AppColors.primary),
              onPressed: () {},
            ),
          );
        },
      ),
    );
  }
}
