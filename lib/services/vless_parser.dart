import 'dart:convert';
import '../models/vpn_config.dart';

class VlessParser {
  static const int socksPort = 10808;
  static const int httpPort = 10809;
  static const int apiPort = 10085;

  /// Converts a VpnConfig (vless:// URI) into a complete Xray-core JSON configuration
  static String buildXrayConfigJson(VpnConfig config) {
    final uri = Uri.tryParse(config.rawUri);
    if (uri == null || uri.scheme.toLowerCase() != 'vless') {
      throw Exception('فرمت لینک VLESS نامعتبر است');
    }

    final uuid = uri.userInfo;
    final host = uri.host;
    final port = uri.hasPort ? uri.port : 443;
    final params = uri.queryParameters;

    final encryption = params['encryption'] ?? 'none';
    final flow = params['flow'] ?? '';
    final network = (params['type'] ?? params['net'] ?? 'tcp').toLowerCase();
    final security = (params['security'] ?? 'none').toLowerCase();

    final sni = params['sni'] ?? params['peer'] ?? host;
    final fp = params['fp'] ?? 'chrome';
    final alpnRaw = params['alpn'] ?? '';
    final allowInsecure = params['allowInsecure'] == '1' || params['allowInsecure'] == 'true';

    // Reality specific parameters
    final pbk = params['pbk'] ?? '';
    final sid = params['sid'] ?? '';
    final spx = params['spx'] ?? '/';

    // Transport specific parameters
    final path = params['path'] ?? '/';
    final hostHeader = params['host'] ?? '';
    final serviceName = params['serviceName'] ?? '';
    final mode = params['mode'] ?? 'auto';
    final headerType = params['headerType'] ?? 'none';

    final Map<String, dynamic> userObj = {
      'id': uuid,
      'encryption': encryption,
    };
    if (flow.isNotEmpty) {
      userObj['flow'] = flow;
    }

    final Map<String, dynamic> streamSettings = {
      'network': network,
      'security': security,
    };

    // Security settings (TLS / Reality)
    if (security == 'tls') {
      final tlsSettings = <String, dynamic>{
        'serverName': sni,
        'fingerprint': fp,
        'allowInsecure': allowInsecure,
      };
      if (alpnRaw.isNotEmpty) {
        tlsSettings['alpn'] = alpnRaw.split(',').map((e) => e.trim()).toList();
      }
      streamSettings['tlsSettings'] = tlsSettings;
    } else if (security == 'reality') {
      streamSettings['realitySettings'] = {
        'show': false,
        'fingerprint': fp,
        'serverName': sni,
        'publicKey': pbk,
        'shortId': sid,
        'spiderX': spx,
      };
    }

    // Transport settings
    switch (network) {
      case 'ws':
        streamSettings['wsSettings'] = {
          'path': path,
          if (hostHeader.isNotEmpty) 'headers': {'Host': hostHeader},
        };
        break;
      case 'grpc':
        streamSettings['grpcSettings'] = {
          'serviceName': serviceName,
          'multiMode': mode == 'multi',
        };
        break;
      case 'httpupgrade':
        streamSettings['httpupgradeSettings'] = {
          'path': path,
          if (hostHeader.isNotEmpty) 'host': hostHeader,
        };
        break;
      case 'xhttp':
      case 'splithttp':
        streamSettings['xhttpSettings'] = {
          'path': path,
          if (hostHeader.isNotEmpty) 'host': hostHeader,
          'mode': mode,
        };
        break;
      case 'tcp':
      default:
        if (headerType == 'http') {
          streamSettings['tcpSettings'] = {
            'header': {
              'type': 'http',
              'request': {
                'path': [path],
                if (hostHeader.isNotEmpty)
                  'headers': {
                    'Host': [hostHeader],
                  },
              },
            },
          };
        }
        break;
    }

    final fullConfig = {
      'log': {
        'loglevel': 'warning',
      },
      'stats': {},
      'api': {
        'tag': 'api',
        'services': ['StatsService'],
      },
      'policy': {
        'levels': {
          '0': {
            'statsUserUplink': true,
            'statsUserDownlink': true,
          },
        },
        'system': {
          'statsInboundUplink': true,
          'statsInboundDownlink': true,
          'statsOutboundUplink': true,
          'statsOutboundDownlink': true,
        },
      },
      'inbounds': [
        {
          'tag': 'socks-in',
          'listen': '127.0.0.1',
          'port': socksPort,
          'protocol': 'socks',
          'settings': {
            'auth': 'noauth',
            'udp': true,
          },
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls', 'quic'],
          },
        },
        {
          'tag': 'http-in',
          'listen': '127.0.0.1',
          'port': httpPort,
          'protocol': 'http',
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls', 'quic'],
          },
        },
        {
          'tag': 'api-in',
          'listen': '127.0.0.1',
          'port': apiPort,
          'protocol': 'dokodemo-door',
          'settings': {
            'address': '127.0.0.1',
          },
        },
      ],
      'outbounds': [
        {
          'tag': 'proxy',
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {
                'address': host,
                'port': port,
                'users': [userObj],
              },
            ],
          },
          'streamSettings': streamSettings,
        },
        {
          'tag': 'direct',
          'protocol': 'freedom',
        },
        {
          'tag': 'block',
          'protocol': 'blackhole',
        },
      ],
      'routing': {
        'domainStrategy': 'AsIs',
        'rules': [
          {
            'type': 'field',
            'inboundTag': ['api-in'],
            'outboundTag': 'api',
          },
          {
            'type': 'field',
            'ip': ['geoip:private'],
            'outboundTag': 'direct',
          },
        ],
      },
    };

    return const JsonEncoder.withIndent('  ').convert(fullConfig);
  }
}
