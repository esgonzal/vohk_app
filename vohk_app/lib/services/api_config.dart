class ApiConfig {
  static const bool useLocal = false;
  static const String _prod = 'https://api.vohk.cl/api';
  static const String _local = 'http://10.10.11.49:8080/api';
  static String get baseUrl => useLocal ? _local : _prod;

  static Uri intercomTalkUri(String deviceId) {
    final base = Uri.parse(baseUrl);
    return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '${base.path}/intercom-talk', queryParameters: {'deviceId': deviceId});
  }
}
