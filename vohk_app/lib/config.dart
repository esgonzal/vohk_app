class AppConfig {
  static const String apiBase = 'https://api.vohk.cl';

  static const List<Map<String, String>> cameras = [
    {'name': 'Camara 1', 'url': '$apiBase/cam1/', 'snapshot': 'https://api.vohk.cl/snapshots/cam1.jpg',},
    {'name': 'Camara 2', 'url': '$apiBase/cam2/', 'snapshot': 'https://api.vohk.cl/snapshots/cam2.jpg',},
  ];

  static const List<Map<String, String>> intercoms = [
    {'name': 'Intercom Principal', 'url': '$apiBase/cam5/', 'snapshot': 'https://api.vohk.cl/snapshots/cam5.jpg',},
    {'name': 'Intercom Secundario', 'url': '$apiBase/cam4/', 'snapshot': 'https://api.vohk.cl/snapshots/cam4.jpg',},
  ];
}
