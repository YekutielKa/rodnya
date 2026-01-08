class AppConfig {
  static const String appName = 'Rodnya';
  static const String apiBaseUrl = 'https://rodnya-production.up.railway.app/api/v1';
  static const String wsUrl = 'https://rodnya-production.up.railway.app';
  
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Pagination
  static const int defaultPageSize = 50;
  static const int messagesPageSize = 50;
  
  // OTP
  static const int otpLength = 6;
  static const Duration otpResendDelay = Duration(seconds: 60);
  
  // Media
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxVideoSize = 50 * 1024 * 1024; // 50MB
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  static const Duration maxVoiceMessageDuration = Duration(minutes: 5);
  
  // WebRTC
  static const Map<String, dynamic> iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };
}
