import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../core/api/call_service.dart';

// Events
abstract class CallEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class InitiateCallEvent extends CallEvent {
  final String recipientId;
  final String recipientName;
  final String? recipientAvatar;
  final CallType callType;
  
  InitiateCallEvent({
    required this.recipientId,
    required this.recipientName,
    this.recipientAvatar,
    required this.callType,
  });
  
  @override
  List<Object?> get props => [recipientId, callType];
}

class AcceptCallEvent extends CallEvent {}

class RejectCallEvent extends CallEvent {}

class EndCallEvent extends CallEvent {}

class ToggleMuteEvent extends CallEvent {}

class ToggleSpeakerEvent extends CallEvent {}

class ToggleVideoEvent extends CallEvent {}

class SwitchCameraEvent extends CallEvent {}

class CallStateChangedEvent extends CallEvent {
  final CallState state;
  CallStateChangedEvent(this.state);
  
  @override
  List<Object?> get props => [state];
}

class IncomingCallEvent extends CallEvent {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final CallType callType;
  
  IncomingCallEvent({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.callType,
  });
  
  @override
  List<Object?> get props => [callId, callerId, callType];
}

// States
abstract class CallBlocState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CallIdleState extends CallBlocState {}

class CallOutgoingState extends CallBlocState {
  final String recipientId;
  final String recipientName;
  final String? recipientAvatar;
  final CallType callType;
  final MediaStream? localStream;
  
  CallOutgoingState({
    required this.recipientId,
    required this.recipientName,
    this.recipientAvatar,
    required this.callType,
    this.localStream,
  });
  
  @override
  List<Object?> get props => [recipientId, callType, localStream];
}

class CallIncomingState extends CallBlocState {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final CallType callType;
  
  CallIncomingState({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.callType,
  });
  
  @override
  List<Object?> get props => [callId, callerId, callType];
}

class CallConnectingState extends CallBlocState {
  final String remoteName;
  final String? remoteAvatar;
  final CallType callType;
  final MediaStream? localStream;
  
  CallConnectingState({
    required this.remoteName,
    this.remoteAvatar,
    required this.callType,
    this.localStream,
  });
  
  @override
  List<Object?> get props => [remoteName, callType, localStream];
}

class CallConnectedState extends CallBlocState {
  final String remoteName;
  final String? remoteAvatar;
  final CallType callType;
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isVideoEnabled;
  final Duration duration;
  
  CallConnectedState({
    required this.remoteName,
    this.remoteAvatar,
    required this.callType,
    this.localStream,
    this.remoteStream,
    this.isMuted = false,
    this.isSpeakerOn = false,
    this.isVideoEnabled = true,
    this.duration = Duration.zero,
  });
  
  CallConnectedState copyWith({
    MediaStream? localStream,
    MediaStream? remoteStream,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isVideoEnabled,
    Duration? duration,
  }) {
    return CallConnectedState(
      remoteName: remoteName,
      remoteAvatar: remoteAvatar,
      callType: callType,
      localStream: localStream ?? this.localStream,
      remoteStream: remoteStream ?? this.remoteStream,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      duration: duration ?? this.duration,
    );
  }
  
  @override
  List<Object?> get props => [remoteName, callType, isMuted, isSpeakerOn, isVideoEnabled, duration];
}

class CallEndedState extends CallBlocState {
  final String? reason;
  CallEndedState({this.reason});
  
  @override
  List<Object?> get props => [reason];
}

// BLoC
class CallBloc extends Bloc<CallEvent, CallBlocState> {
  final CallService _callService;
  StreamSubscription<CallState>? _stateSubscription;
  StreamSubscription<MediaStream?>? _localStreamSubscription;
  StreamSubscription<MediaStream?>? _remoteStreamSubscription;
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;
  
  String _remoteName = '';
  String? _remoteAvatar;
  CallType _callType = CallType.audio;

  CallBloc(this._callService) : super(CallIdleState()) {
    on<InitiateCallEvent>(_onInitiateCall);
    on<AcceptCallEvent>(_onAcceptCall);
    on<RejectCallEvent>(_onRejectCall);
    on<EndCallEvent>(_onEndCall);
    on<ToggleMuteEvent>(_onToggleMute);
    on<ToggleSpeakerEvent>(_onToggleSpeaker);
    on<ToggleVideoEvent>(_onToggleVideo);
    on<SwitchCameraEvent>(_onSwitchCamera);
    on<CallStateChangedEvent>(_onCallStateChanged);
    on<IncomingCallEvent>(_onIncomingCall);
    
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    _stateSubscription = _callService.stateStream.listen((callState) {
      add(CallStateChangedEvent(callState));
    });
    
    _localStreamSubscription = _callService.localStream.listen((stream) {
      _updateStreamState();
    });
    
    _remoteStreamSubscription = _callService.remoteStream.listen((stream) {
      _updateStreamState();
    });
  }

  void _updateStreamState() {
    if (state is CallConnectedState) {
      final current = state as CallConnectedState;
      emit(current.copyWith(
        localStream: _callService.localMediaStream,
        remoteStream: _callService.remoteMediaStream,
      ));
    }
  }

  Future<void> _onInitiateCall(InitiateCallEvent event, Emitter<CallBlocState> emit) async {
    _remoteName = event.recipientName;
    _remoteAvatar = event.recipientAvatar;
    _callType = event.callType;
    
    emit(CallOutgoingState(
      recipientId: event.recipientId,
      recipientName: event.recipientName,
      recipientAvatar: event.recipientAvatar,
      callType: event.callType,
    ));
    
    await _callService.initiateCall(event.recipientId, event.callType);
  }

  Future<void> _onAcceptCall(AcceptCallEvent event, Emitter<CallBlocState> emit) async {
    await _callService.acceptCall();
  }

  void _onRejectCall(RejectCallEvent event, Emitter<CallBlocState> emit) {
    _callService.rejectCall();
    emit(CallIdleState());
  }

  void _onEndCall(EndCallEvent event, Emitter<CallBlocState> emit) {
    _stopDurationTimer();
    _callService.endCall();
  }

  void _onToggleMute(ToggleMuteEvent event, Emitter<CallBlocState> emit) {
    _callService.toggleMute();
    if (state is CallConnectedState) {
      emit((state as CallConnectedState).copyWith(isMuted: _callService.isMuted));
    }
  }

  void _onToggleSpeaker(ToggleSpeakerEvent event, Emitter<CallBlocState> emit) {
    _callService.toggleSpeaker();
    if (state is CallConnectedState) {
      emit((state as CallConnectedState).copyWith(isSpeakerOn: _callService.isSpeakerOn));
    }
  }

  void _onToggleVideo(ToggleVideoEvent event, Emitter<CallBlocState> emit) {
    _callService.toggleVideo();
    if (state is CallConnectedState) {
      emit((state as CallConnectedState).copyWith(isVideoEnabled: _callService.isVideoEnabled));
    }
  }

  Future<void> _onSwitchCamera(SwitchCameraEvent event, Emitter<CallBlocState> emit) async {
    await _callService.switchCamera();
  }

  void _onIncomingCall(IncomingCallEvent event, Emitter<CallBlocState> emit) {
    _remoteName = event.callerName;
    _remoteAvatar = event.callerAvatar;
    _callType = event.callType;
    
    emit(CallIncomingState(
      callId: event.callId,
      callerId: event.callerId,
      callerName: event.callerName,
      callerAvatar: event.callerAvatar,
      callType: event.callType,
    ));
  }

  void _onCallStateChanged(CallStateChangedEvent event, Emitter<CallBlocState> emit) {
    switch (event.state) {
      case CallState.idle:
        _stopDurationTimer();
        emit(CallIdleState());
        break;
      case CallState.outgoing:
        emit(CallOutgoingState(
          recipientId: _callService.remoteUserId ?? '',
          recipientName: _remoteName,
          recipientAvatar: _remoteAvatar,
          callType: _callType,
          localStream: _callService.localMediaStream,
        ));
        break;
      case CallState.incoming:
        // Handled by IncomingCallEvent
        break;
      case CallState.connecting:
        emit(CallConnectingState(
          remoteName: _remoteName,
          remoteAvatar: _remoteAvatar,
          callType: _callType,
          localStream: _callService.localMediaStream,
        ));
        break;
      case CallState.connected:
        _startDurationTimer(emit);
        emit(CallConnectedState(
          remoteName: _remoteName,
          remoteAvatar: _remoteAvatar,
          callType: _callType,
          localStream: _callService.localMediaStream,
          remoteStream: _callService.remoteMediaStream,
          isMuted: _callService.isMuted,
          isSpeakerOn: _callService.isSpeakerOn,
          isVideoEnabled: _callService.isVideoEnabled,
          duration: _callDuration,
        ));
        break;
      case CallState.ended:
        _stopDurationTimer();
        emit(CallEndedState());
        Future.delayed(const Duration(seconds: 2), () {
          if (!isClosed) add(CallStateChangedEvent(CallState.idle));
        });
        break;
    }
  }

  void _startDurationTimer(Emitter<CallBlocState> emit) {
    _callDuration = Duration.zero;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration += const Duration(seconds: 1);
      if (state is CallConnectedState) {
        emit((state as CallConnectedState).copyWith(duration: _callDuration));
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callDuration = Duration.zero;
  }

  @override
  Future<void> close() {
    _stateSubscription?.cancel();
    _localStreamSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    _stopDurationTimer();
    return super.close();
  }
}
