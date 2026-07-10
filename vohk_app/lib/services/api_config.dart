class ApiConfig {
  static const bool useLocal = false;
  static const String _prod = 'https://api.vohk.cl/app';
  static const String _local = 'http://10.10.11.51:8080/app';
  static String get baseUrl => useLocal ? _local : _prod;
}
