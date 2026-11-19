import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/vpn_config.dart';
import 'vless_parser.dart';
import 'windows_proxy_service.dart';

enum VpnConnectionState {
  disconnected,
  connecting,
  connected,
}

class VpnTelemetry {
  final VpnConnectionState state;
  final int downloadSpeed;
  final int uploadSpeed;
  final int totalDownload;
  final int totalUpload;
  final String duration;

  const VpnTelemetry({
    this.state = VpnConnectionState.disconnected,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.totalDownload = 0,
    this.totalUpload = 0,
    this.duration = '00:00:00',
  });
}

class VpnService {
  final void Function(VpnTelemetry telemetry) onStatusUpdate;

  Process? _xrayProcess;
  Timer? _telemetryTimer;
  VpnTelemetry _current = const VpnTelemetry();

  int _elapsedSeconds = 0;
  int _lastDownloadBytes = 0;
  int _lastUploadBytes = 0;

  VpnService({required this.onStatusUpdate});

  /// Resolves xray.exe placed alongside the compiled Windows executable
  String _getXrayExecutablePath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final separator = Platform.pathSeparator;
    return '$exeDir${separator}xray.exe';
  }

  /// Measures TCP handshake latency to the VPN server
  Future<int?> measurePing(VpnConfig config) async {
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(
        config.host,
        config.port,
        timeout: const Duration(seconds: 4),
      );
      stopwatch.stop();
      await socket.close();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  Future<void> connect(VpnConfig config) async {
    if (_current.state != VpnConnectionState.disconnected) {
      await disconnect();
    }

    _emitState(VpnConnectionState.connecting);

    try {
      final xrayPath = _getXrayExecutablePath();
      if (!await File(xrayPath).exists()) {
        throw Exception('فایل هسته xray.exe در کنار برنامه یافت نشد');
      }

      // Build and write Xray config.json to temp directory
      final jsonConfig = VlessParser.buildXrayConfigJson(config);
      final tempDir = await getTemporaryDirectory();
      final configFile = File('${tempDir.path}${Platform.pathSeparator}vira_xray_config.json');
      await configFile.writeAsString(jsonConfig);

      // Start Xray-core process
      _xrayProcess = await Process.start(
        xrayPath,
        ['run', '-c', configFile.path],
        workingDirectory: File(xrayPath).parent.path,
      );

      // Listen for unexpected exit
      bool exitedEarly = false;
      String stderrLog = '';
      _xrayProcess!.stderr.transform(utf8.decoder).listen((data) {
        stderrLog += data;
      });
      _xrayProcess!.exitCode.then((code) {
        exitedEarly = true;
        if (_current.state != VpnConnectionState.disconnected) {
          disconnect();
        }
      });

      // Wait briefly to confirm Xray initialized cleanly
      await Future.delayed(const Duration(milliseconds: 700));
      if (exitedEarly) {
        throw Exception(
          stderrLog.isNotEmpty
              ? 'خطای هسته Xray: ${stderrLog.split('\n').first}'
              : 'هسته Xray متوقف شد',
        );
      }

      // Enable Windows System Proxy
      await WindowsProxyService.enableProxy(
        host: '127.0.0.1',
        port: VlessParser.httpPort,
      );

      _elapsedSeconds = 0;
      _lastDownloadBytes = 0;
      _lastUploadBytes = 0;
      _emitState(VpnConnectionState.connected);
      _startTelemetryPolling(xrayPath);
    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _telemetryTimer?.cancel();
    _telemetryTimer = null;

    await WindowsProxyService.disableProxy();

    if (_xrayProcess != null) {
      _xrayProcess!.kill(ProcessSignal.sigkill);
      _xrayProcess = null;
    }

    _elapsedSeconds = 0;
    _lastDownloadBytes = 0;
    _lastUploadBytes = 0;
    _current = const VpnTelemetry(state: VpnConnectionState.disconnected);
    onStatusUpdate(_current);
  }

  void _startTelemetryPolling(String xrayPath) {
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_current.state != VpnConnectionState.connected) return;

      _elapsedSeconds++;
      final h = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
      final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
      final formattedDuration = '$h:$m:$s';

      int totalDown = _lastDownloadBytes;
      int totalUp = _lastUploadBytes;

      try {
        final result = await Process.run(
          xrayPath,
          ['api', 'statsquery', '--server=127.0.0.1:${VlessParser.apiPort}'],
        ).timeout(const Duration(milliseconds: 800));

        if (result.exitCode == 0) {
          final parsed = jsonDecode(result.stdout.toString());
          final stats = parsed['stat'];
          if (stats is List) {
            for (final item in stats) {
              if (item is Map<String, dynamic>) {
                final name = item['name']?.toString() ?? '';
                final value = int.tryParse(item['value']?.toString() ?? '0') ?? 0;
                if (name == 'outbound>>>proxy>>>traffic>>>downlink') {
                  totalDown = value;
                } else if (name == 'outbound>>>proxy>>>traffic>>>uplink') {
                  totalUp = value;
                }
              }
            }
          }
        }
      } catch (_) {
        // Keep previous counters if stats query momentarily times out
      }

      final downSpeed = (totalDown - _lastDownloadBytes).clamp(0, 1 << 62);
      final upSpeed = (totalUp - _lastUploadBytes).clamp(0, 1 << 62);

      _lastDownloadBytes = totalDown;
      _lastUploadBytes = totalUp;

      _current = VpnTelemetry(
        state: VpnConnectionState.connected,
        downloadSpeed: downSpeed,
        uploadSpeed: upSpeed,
        totalDownload: totalDown,
        totalUpload: totalUp,
        duration: formattedDuration,
      );
      onStatusUpdate(_current);
    });
  }

  void _emitState(VpnConnectionState state) {
    _current = VpnTelemetry(
      state: state,
      downloadSpeed: _current.downloadSpeed,
      uploadSpeed: _current.uploadSpeed,
      totalDownload: _current.totalDownload,
      totalUpload: _current.totalUpload,
      duration: _current.duration,
    );
    onStatusUpdate(_current);
  }

  void dispose() {
    disconnect();
  }
}
