import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import 'socket_service.dart';

enum CallState { idle, outgoing, incoming, connecting, connected, ended }
enum CallType { audio, video }

class CallService {
  final SocketService _socketService;
  
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  String? _currentCallId;
  String? _remoteUserId;
  CallType _callType = CallType.audio;
  CallState _callState = CallState.idle;
  
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  
  final _stateController = StreamController<CallState>.broadcast();
  final _remoteStreamController = StreamController<MediaStream?>.broadcast();
  final _localStreamController = StreamController<MediaStream?>.broadcast();
  
  Stream<CallState> get stateStream => _stateController.stream;
  Stream<MediaStream?> get remoteStream => _remoteStreamController.stream;
  Stream<MediaStream?> get localStream => _localStreamController.stream;
  
  CallState get callState => _callState;
  String? get currentCallId => _currentCallId;
  String? get remoteUserId => _remoteUserId;
  CallType get callType => _callType;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoEnabled => _isVideoEnabled;
  MediaStream? get localMediaStream => _localStream;
  MediaStream? get remoteMediaStream => _remoteStream;

  CallService(this._socketService) {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    _socketService.onCall((data) {
      final event = data['event'] as String?;
      switch (event) {
        case 'incoming':
          _handleIncomingCall(data);
          break;
        case 'accepted':
          _handleCallAccepted(data);
          break;
        case 'rejected':
          _handleCallRejected(data);
          break;
        case 'ended':
          _handleCallEnded(data);
          break;
        case 'signal':
          _handleSignal(data);
          break;
        case 'ice-candidate':
          _handleIceCandidate(data);
          break;
      }
    });
  }

  Future<void> initiateCall(String recipientId, CallType type) async {
    if (_callState != CallState.idle) return;
    
    _callType = type;
    _remoteUserId = recipientId;
    _currentCallId = const Uuid().v4();
    _updateState(CallState.outgoing);
    
    await _initializeMedia();
    await _createPeerConnection();
    
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    _socketService.initiateCall(
      recipientId: recipientId,
      callType: type == CallType.video ? 'video' : 'audio',
      callId: _currentCallId!,
    );
    
    _socketService.sendSignal(_currentCallId!, recipientId, {
      'type': 'offer',
      'sdp': offer.sdp,
    });
  }

  Future<void> acceptCall() async {
    if (_callState != CallState.incoming || _currentCallId == null) return;
    
    _updateState(CallState.connecting);
    await _initializeMedia();
    await _createPeerConnection();
    
    _socketService.acceptCall(_currentCallId!);
  }

  void rejectCall() {
    if (_currentCallId == null) return;
    _socketService.rejectCall(_currentCallId!);
    _cleanup();
  }

  void endCall() {
    if (_currentCallId == null) return;
    if (_remoteUserId != null) {
      _socketService.endCall(_currentCallId!);
    }
    _cleanup();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    _localStream?.getAudioTracks().forEach((track) {
      Helper.setSpeakerphoneOn(_isSpeakerOn);
    });
  }

  void toggleVideo() {
    if (_callType != CallType.video) return;
    _isVideoEnabled = !_isVideoEnabled;
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = _isVideoEnabled;
    });
  }

  Future<void> switchCamera() async {
    if (_callType != CallType.video || _localStream == null) return;
    _isFrontCamera = !_isFrontCamera;
    final videoTrack = _localStream!.getVideoTracks().first;
    await Helper.switchCamera(videoTrack);
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    if (_callState != CallState.idle) {
      // Already in a call, reject
      final callId = data['callId'] as String?;
      if (callId != null) {
        _socketService.rejectCall(callId);
      }
      return;
    }
    
    _currentCallId = data['callId'] as String?;
    _remoteUserId = data['callerId'] as String?;
    _callType = data['callType'] == 'video' ? CallType.video : CallType.audio;
    _updateState(CallState.incoming);
  }

  Future<void> _handleCallAccepted(Map<String, dynamic> data) async {
    if (_callState != CallState.outgoing) return;
    _updateState(CallState.connecting);
  }

  void _handleCallRejected(Map<String, dynamic> data) {
    _cleanup();
  }

  void _handleCallEnded(Map<String, dynamic> data) {
    _cleanup();
  }

  Future<void> _handleSignal(Map<String, dynamic> data) async {
    final signal = data['signal'] as Map<String, dynamic>?;
    if (signal == null || _peerConnection == null) return;
    
    final type = signal['type'] as String?;
    final sdp = signal['sdp'] as String?;
    
    if (type == 'offer' && sdp != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, 'offer'),
      );
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      _socketService.sendSignal(_currentCallId!, _remoteUserId!, {
        'type': 'answer',
        'sdp': answer.sdp,
      });
    } else if (type == 'answer' && sdp != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, 'answer'),
      );
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> data) async {
    final candidateData = data['candidate'] as Map<String, dynamic>?;
    if (candidateData == null || _peerConnection == null) return;
    
    final candidate = RTCIceCandidate(
      candidateData['candidate'] as String?,
      candidateData['sdpMid'] as String?,
      candidateData['sdpMLineIndex'] as int?,
    );
    await _peerConnection!.addCandidate(candidate);
  }

  Future<void> _initializeMedia() async {
    final constraints = {
      'audio': true,
      'video': _callType == CallType.video ? {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      } : false,
    };
    
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    _localStreamController.add(_localStream);
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(AppConfig.iceServers);
    
    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
    
    _peerConnection!.onIceCandidate = (candidate) {
      if (_remoteUserId != null && _currentCallId != null) {
        _socketService.sendIceCandidate(_currentCallId!, _remoteUserId!, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };
    
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _remoteStreamController.add(_remoteStream);
      }
    };
    
    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _updateState(CallState.connected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _cleanup();
      }
    };
  }

  void _updateState(CallState state) {
    _callState = state;
    _stateController.add(state);
  }

  void _cleanup() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    
    _remoteStream?.dispose();
    _remoteStream = null;
    
    _peerConnection?.close();
    _peerConnection = null;
    
    _currentCallId = null;
    _remoteUserId = null;
    _isMuted = false;
    _isSpeakerOn = false;
    _isVideoEnabled = true;
    
    _localStreamController.add(null);
    _remoteStreamController.add(null);
    _updateState(CallState.ended);
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_callState == CallState.ended) {
        _updateState(CallState.idle);
      }
    });
  }

  void dispose() {
    _cleanup();
    _stateController.close();
    _remoteStreamController.close();
    _localStreamController.close();
  }
}
