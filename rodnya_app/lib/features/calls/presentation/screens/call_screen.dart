import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';

class CallScreen extends StatelessWidget {
  final String callId;
  final bool isVideo;
  final bool isIncoming;

  const CallScreen({super.key, required this.callId, this.isVideo = false, this.isIncoming = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey900,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const CircleAvatar(radius: 60, backgroundColor: AppColors.primary, child: Icon(Icons.person, size: 60, color: AppColors.white)),
            const SizedBox(height: 24),
            const Text('User Name', style: TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(isIncoming ? 'Входящий звонок...' : 'Вызов...', style: const TextStyle(color: AppColors.grey400, fontSize: 16)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallButton(icon: Icons.mic_off, label: 'Микрофон', onPressed: () {}),
                _CallButton(icon: Icons.volume_up, label: 'Динамик', onPressed: () {}),
                if (isVideo) _CallButton(icon: Icons.videocam_off, label: 'Камера', onPressed: () {}),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isIncoming) ...[
                  FloatingActionButton(
                    backgroundColor: AppColors.success,
                    onPressed: () {},
                    child: const Icon(Icons.call, color: AppColors.white),
                  ),
                  const SizedBox(width: 40),
                ],
                FloatingActionButton(
                  backgroundColor: AppColors.error,
                  onPressed: () => Navigator.pop(context),
                  child: const Icon(Icons.call_end, color: AppColors.white),
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _CallButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: AppColors.grey800, shape: BoxShape.circle),
          child: IconButton(icon: Icon(icon, color: AppColors.white), onPressed: onPressed),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
      ],
    );
  }
}
