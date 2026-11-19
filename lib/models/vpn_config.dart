class VpnConfig {
  final String id;
  final String title;
  final String host;
  final int port;
  final String rawUri;
  final String? iconUrl;
  int? pingMs;
  bool isPinging;

  VpnConfig({
    required this.id,
    required this.title,
    required this.host,
    required this.port,
    required this.rawUri,
    this.iconUrl,
    this.pingMs,
    this.isPinging = false,
  });

  String get serverDisplay => '$host:$port';

  /// Parses a single VLESS URI (vless://uuid@host:port?params#Title)
  factory VpnConfig.fromVlessUri(
    String uri, {
    int index = 0,
    String? customTitle,
    String? customIcon,
  }) {
    final trimmed = uri.trim();
    final parsed = Uri.tryParse(trimmed);

    String host = 'unknown';
    int port = 443;
    String title = customTitle ?? 'Server #${index + 1}';

    if (parsed != null) {
      if (parsed.host.isNotEmpty) {
        host = parsed.host;
      }
      if (parsed.hasPort) {
        port = parsed.port;
      }
      if ((customTitle == null || customTitle.isEmpty) && parsed.fragment.isNotEmpty) {
        title = Uri.decodeComponent(parsed.fragment);
      }
    }

    return VpnConfig(
      id: '${host}_${port}_$index',
      title: title,
      host: host,
      port: port,
      rawUri: trimmed,
      iconUrl: customIcon,
    );
  }

  /// Parses JSON item from API
  factory VpnConfig.fromJson(Map<String, dynamic> json, int index) {
    final uri = (json['config'] ?? json['link'] ?? json['uri'] ?? json['url'] ?? '').toString();
    final title = (json['title'] ?? json['name'] ?? json['remark'] ?? '').toString();
    final icon = (json['icon'] ?? json['flag'] ?? json['image'])?.toString();

    if (uri.startsWith('vless://')) {
      final base = VpnConfig.fromVlessUri(
        uri,
        index: index,
        customTitle: title.isNotEmpty ? title : null,
        customIcon: icon,
      );
      final serverField = (json['server'] ?? json['host'] ?? '').toString();
      if (serverField.isNotEmpty && base.host == 'unknown') {
        return VpnConfig(
          id: base.id,
          title: base.title,
          host: serverField,
          port: int.tryParse((json['port'] ?? '443').toString()) ?? 443,
          rawUri: uri,
          iconUrl: icon,
        );
      }
      return base;
    }

    final host = (json['server'] ?? json['host'] ?? json['address'] ?? 'unknown').toString();
    final port = int.tryParse((json['port'] ?? '443').toString()) ?? 443;

    return VpnConfig(
      id: '${host}_${port}_$index',
      title: title.isNotEmpty ? title : 'Server #${index + 1}',
      host: host,
      port: port,
      rawUri: uri,
      iconUrl: icon,
    );
  }
}
