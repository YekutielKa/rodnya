import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';

class IncomingCallOverlay extends StatefulWidget {
  final String callerName;
  final String? callerAvatar;
  final bool isVideo;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallOverlay({
    super.key,
    required this.callerName,
    this.callerAvatar,
    this.isVideo = false,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // Avatar with pulse animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      backgroundImage: widget.callerAvatar != null ? NetworkImage(widget.callerAvatar!) : null,
                      child: widget.callerAvatar == null
                          ? Text(
                              widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 48, color: AppColors.primary),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            Text(
              widget.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isVideo ? Icons.videocam : Icons.phone,
                  color: Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isVideo ? 'Видеозвонок' : 'Аудиозвонок',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
              ],
            ),
            
            const Spacer(flex: 3),
            
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'Отклонить',
                    onPressed: widget.onReject,
                  ),
                  _buildCallButton(
                    icon: Icons.call,
                    color: Colors.green,
                    label: 'Ответить',
                    onPressed: widget.onAccept,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 70,
          height: 70,
          child: FloatingActionButton(
            heroTag: label,
            backgroundColor: color,
            onPressed: onPressed,
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
      ],
    );
  }
}

// Helper to show incoming call overlay
void showIncomingCallOverlay(
  BuildContext context, {
  required String callerName,
  String? callerAvatar,
  bool isVideo = false,
  required VoidCallback onAccept,
  required VoidCallback onReject,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (context) => IncomingCallOverlay(
      callerName: callerName,
      callerAvatar: callerAvatar,
      isVideo: isVideo,
      onAccept: () {
        Navigator.of(context).pop();
        onAccept();
      },
      onReject: () {
        Navigator.of(context).pop();
        onReject();
      },
    ),
  );
}
