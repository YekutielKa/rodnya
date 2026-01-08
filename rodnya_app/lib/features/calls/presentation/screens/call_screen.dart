import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../core/config/theme.dart';
import '../../../../core/api/call_service.dart';
import '../bloc/call_bloc.dart';

class CallScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String? recipientAvatar;
  final bool isVideo;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.recipientAvatar,
    this.isVideo = false,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _renderersInitialized = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    if (!widget.isIncoming) {
      _initiateCall();
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    setState(() => _renderersInitialized = true);
  }

  void _initiateCall() {
    context.read<CallBloc>().add(InitiateCallEvent(
      recipientId: widget.recipientId,
      recipientName: widget.recipientName,
      recipientAvatar: widget.recipientAvatar,
      callType: widget.isVideo ? CallType.video : CallType.audio,
    ));
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallBloc, CallBlocState>(
      listener: (context, state) {
        if (state is CallIdleState) {
          Navigator.of(context).pop();
        }
        if (state is CallConnectedState) {
          if (state.localStream != null) {
            _localRenderer.srcObject = state.localStream;
          }
          if (state.remoteStream != null) {
            _remoteRenderer.srcObject = state.remoteStream;
          }
        }
        if (state is CallOutgoingState && state.localStream != null) {
          _localRenderer.srcObject = state.localStream;
        }
        if (state is CallConnectingState && state.localStream != null) {
          _localRenderer.srcObject = state.localStream;
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.grey900,
          body: SafeArea(
            child: Stack(
              children: [
                // Video backgrounds
                if (widget.isVideo && _renderersInitialized) ...[
                  // Remote video (full screen)
                  if (state is CallConnectedState && state.remoteStream != null)
                    Positioned.fill(
                      child: RTCVideoView(
                        _remoteRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    )
                  else
                    _buildAudioBackground(state),
                  
                  // Local video (small)
                  if (state is CallConnectedState || state is CallOutgoingState || state is CallConnectingState)
                    Positioned(
                      top: 20,
                      right: 20,
                      width: 120,
                      height: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.grey800,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: RTCVideoView(
                            _localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                        ),
                      ),
                    ),
                ] else
                  _buildAudioBackground(state),
                
                // UI overlay
                _buildUIOverlay(state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioBackground(CallBlocState state) {
    String statusText = 'Вызов...';
    if (state is CallIncomingState) statusText = 'Входящий звонок';
    if (state is CallConnectingState) statusText = 'Соединение...';
    if (state is CallConnectedState) statusText = _formatDuration(state.duration);
    if (state is CallEndedState) statusText = 'Звонок завершен';

    return Positioned.fill(
      child: Container(
        color: AppColors.grey900,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatar(),
            const SizedBox(height: 24),
            Text(
              widget.recipientName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 60,
      backgroundColor: AppColors.primary.withOpacity(0.2),
      backgroundImage: widget.recipientAvatar != null ? NetworkImage(widget.recipientAvatar!) : null,
      child: widget.recipientAvatar == null
          ? Text(
              widget.recipientName.isNotEmpty ? widget.recipientName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 48, color: AppColors.primary),
            )
          : null,
    );
  }

  Widget _buildUIOverlay(CallBlocState state) {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (widget.isVideo && state is CallConnectedState) ...[
                _buildAvatar(),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.recipientName, style: const TextStyle(color: Colors.white, fontSize: 18)),
                    Text(_formatDuration(state.duration), style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                  ],
                ),
              ],
              const Spacer(),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Control buttons
        _buildControls(state),
        
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildControls(CallBlocState state) {
    final bloc = context.read<CallBloc>();
    
    // Incoming call - accept/reject
    if (state is CallIncomingState) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.call_end,
            color: Colors.red,
            onPressed: () => bloc.add(RejectCallEvent()),
            label: 'Отклонить',
          ),
          _buildActionButton(
            icon: Icons.call,
            color: Colors.green,
            onPressed: () => bloc.add(AcceptCallEvent()),
            label: 'Ответить',
          ),
        ],
      );
    }
    
    // Connected state - full controls
    if (state is CallConnectedState) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: state.isMuted ? Icons.mic_off : Icons.mic,
                isActive: state.isMuted,
                onPressed: () => bloc.add(ToggleMuteEvent()),
                label: 'Микрофон',
              ),
              _buildControlButton(
                icon: state.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                isActive: state.isSpeakerOn,
                onPressed: () => bloc.add(ToggleSpeakerEvent()),
                label: 'Динамик',
              ),
              if (widget.isVideo) ...[
                _buildControlButton(
                  icon: state.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  isActive: !state.isVideoEnabled,
                  onPressed: () => bloc.add(ToggleVideoEvent()),
                  label: 'Камера',
                ),
                _buildControlButton(
                  icon: Icons.cameraswitch,
                  isActive: false,
                  onPressed: () => bloc.add(SwitchCameraEvent()),
                  label: 'Переключить',
                ),
              ],
            ],
          ),
          const SizedBox(height: 30),
          _buildActionButton(
            icon: Icons.call_end,
            color: Colors.red,
            onPressed: () => bloc.add(EndCallEvent()),
            label: 'Завершить',
            size: 70,
          ),
        ],
      );
    }
    
    // Outgoing/Connecting - only end call
    return _buildActionButton(
      icon: Icons.call_end,
      color: Colors.red,
      onPressed: () => bloc.add(EndCallEvent()),
      label: 'Отмена',
      size: 70,
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : AppColors.grey800,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: isActive ? AppColors.grey900 : Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
    double size = 60,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: FloatingActionButton(
            heroTag: label,
            backgroundColor: color,
            onPressed: onPressed,
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }
}
