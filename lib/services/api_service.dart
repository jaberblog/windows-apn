import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vpn_config.dart';

class ApiService {
  static const String endpoint = 'https://virasub.ir/npv/';

  Future<List<VpnConfig>> fetchConfigs() async {
    final response = await http.get(
      Uri.parse(endpoint),
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'ViraVPN-Windows/1.0',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('خطا در دریافت اطلاعات از سرور (کد ${response.statusCode})');
    }

    final body = utf8.decode(response.bodyBytes).trim();
    if (body.isEmpty) {
      return [];
    }

    // 1. Try parsing as JSON (List or Map with data/configs/servers key)
    try {
      final decoded = jsonDecode(body);
      List<dynamic> items = [];

      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['data'] is List) {
          items = decoded['data'];
        } else if (decoded['configs'] is List) {
          items = decoded['configs'];
        } else if (decoded['servers'] is List) {
          items = decoded['servers'];
        }
      }

      if (items.isNotEmpty) {
        final results = <VpnConfig>[];
        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          if (item is Map<String, dynamic>) {
            results.add(VpnConfig.fromJson(item, i));
          } else if (item is String && item.trim().startsWith('vless://')) {
            results.add(VpnConfig.fromVlessUri(item.trim(), index: i));
          }
        }
        return results;
      }
    } catch (_) {
      // Not JSON; fall through to Base64 / plain subscription parsing
    }

    // 2. Try Base64 decoding if not directly containing vless://
    String rawText = body;
    if (!rawText.contains('vless://')) {
      try {
        final normalized = base64.normalize(rawText.replaceAll(RegExp(r'\s+'), ''));
        rawText = utf8.decode(base64Decode(normalized));
      } catch (_) {
        // Keep original text
      }
    }

    // 3. Parse line-by-line VLESS URIs
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.startsWith('vless://'))
        .toList();

    final configs = <VpnConfig>[];
    for (int i = 0; i < lines.length; i++) {
      configs.add(VpnConfig.fromVlessUri(lines[i], index: i));
    }
    return configs;
  }
}
