import 'package:flutter/material.dart';
import '../../core/api/socket_service.dart';
import '../../core/api/call_service.dart';
import 'presentation/screens/call_screen.dart';
import 'presentation/widgets/incoming_call_overlay.dart';
import 'presentation/bloc/call_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CallManager {
  static CallManager? _instance;
  static CallManager get instance => _instance ??= CallManager._();

  CallManager._();

  late SocketService _socketService;
  late CallService _callService;
  late CallBloc _callBloc;
  BuildContext? _context;
  bool _isShowingIncomingCall = false;

  void initialize({
    required SocketService socketService,
    required CallService callService,
    required CallBloc callBloc,
  }) {
    _socketService = socketService;
    _callService = callService;
    _callBloc = callBloc;

    _setupCallListener();
  }

  void setContext(BuildContext context) {
    _context = context;
  }

  void _setupCallListener() {
    _socketService.onCall((data) {
      final event = data['event'] as String?;
      if (event == 'incoming' && !_isShowingIncomingCall && _context != null) {
        _handleIncomingCall(data);
      }
    });
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    if (_context == null) return;

    final callId = data['callId'] as String? ?? '';
    final callerId = data['callerId'] as String? ?? '';
    final callerName = data['callerName'] as String? ?? 'Неизвестный';
    final callerAvatar = data['callerAvatar'] as String?;
    final isVideo = data['callType'] == 'video';

    _isShowingIncomingCall = true;

    _callBloc.add(IncomingCallEvent(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      callType: isVideo ? CallType.video : CallType.audio,
    ));

    showIncomingCallOverlay(
      _context!,
      callerName: callerName,
      callerAvatar: callerAvatar,
      isVideo: isVideo,
      onAccept: () {
        _isShowingIncomingCall = false;
        _navigateToCallScreen(
          recipientId: callerId,
          recipientName: callerName,
          recipientAvatar: callerAvatar,
          isVideo: isVideo,
          isIncoming: true,
        );
        _callBloc.add(AcceptCallEvent());
      },
      onReject: () {
        _isShowingIncomingCall = false;
        _callBloc.add(RejectCallEvent());
      },
    );
  }

  void initiateCall({
    required String recipientId,
    required String recipientName,
    String? recipientAvatar,
    bool isVideo = false,
  }) {
    if (_context == null) return;

    _navigateToCallScreen(
      recipientId: recipientId,
      recipientName: recipientName,
      recipientAvatar: recipientAvatar,
      isVideo: isVideo,
      isIncoming: false,
    );
  }

  void _navigateToCallScreen({
    required String recipientId,
    required String recipientName,
    String? recipientAvatar,
    required bool isVideo,
    required bool isIncoming,
  }) {
    if (_context == null) return;

    Navigator.of(_context!).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: _callBloc,
          child: CallScreen(
            recipientId: recipientId,
            recipientName: recipientName,
            recipientAvatar: recipientAvatar,
            isVideo: isVideo,
            isIncoming: isIncoming,
          ),
        ),
      ),
    );
  }
}
