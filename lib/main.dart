import 'package:flutter/material.dart';
import 'models/vpn_config.dart';
import 'services/api_service.dart';
import 'services/vpn_service.dart';
import 'widgets/connect_button.dart';
import 'widgets/stats_card.dart';
import 'widgets/config_tile.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ViraVpnApp());
}

class ViraVpnApp extends StatelessWidget {
  const ViraVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vira VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF131A2A),
        ),
        fontFamily: 'Segoe UI',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  late final VpnService _vpnService;

  List<VpnConfig> _configs = [];
  VpnConfig? _selectedConfig;
  bool _isLoadingConfigs = true;
  bool _isPingingAll = false;
  String? _errorMessage;

  VpnConnectionState _connectionState = VpnConnectionState.disconnected;
  int _downloadSpeed = 0;
  int _uploadSpeed = 0;
  int _totalDownload = 0;
  int _totalUpload = 0;
  String _duration = '00:00:00';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vpnService = VpnService(
      onStatusUpdate: (status) {
        if (!mounted) return;
        setState(() {
          _connectionState = status.state;
          _downloadSpeed = status.downloadSpeed;
          _uploadSpeed = status.uploadSpeed;
          _totalDownload = status.totalDownload;
          _totalUpload = status.totalUpload;
          _duration = status.duration;
        });
      },
    );
    _loadConfigs();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _vpnService.disconnect();
    }
  }

  Future<void> _loadConfigs() async {
    setState(() {
      _isLoadingConfigs = true;
      _errorMessage = null;
    });

    try {
      final fetched = await _apiService.fetchConfigs();
      if (!mounted) return;
      setState(() {
        _configs = fetched;
        if (_configs.isNotEmpty) {
          _selectedConfig ??= _configs.first;
        }
        _isLoadingConfigs = false;
      });
      if (_configs.isNotEmpty) {
        _pingAllConfigs();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoadingConfigs = false;
      });
    }
  }

  Future<void> _pingSingleConfig(VpnConfig config) async {
    setState(() {
      config.isPinging = true;
    });
    final ping = await _vpnService.measurePing(config);
    if (!mounted) return;
    setState(() {
      config.pingMs = ping;
      config.isPinging = false;
    });
  }

  Future<void> _pingAllConfigs() async {
    if (_isPingingAll || _configs.isEmpty) return;
    setState(() => _isPingingAll = true);

    await Future.wait(_configs.map((c) => _pingSingleConfig(c)));

    if (!mounted) return;
    setState(() => _isPingingAll = false);
  }

  Future<void> _toggleConnection() async {
    if (_connectionState == VpnConnectionState.connected ||
        _connectionState == VpnConnectionState.connecting) {
      await _vpnService.disconnect();
      return;
    }

    if (_selectedConfig == null) {
      _showSnack('لطفاً ابتدا یک سرور انتخاب کنید');
      return;
    }

    try {
      await _vpnService.connect(_selectedConfig!);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vpnService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 820;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1626),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Vira VPN',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _isPingingAll ? null : _pingAllConfigs,
            icon: _isPingingAll
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed_rounded, size: 18),
            label: const Text('تست پینگ همه'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'بروزرسانی لیست سرورها',
            onPressed: _isLoadingConfigs ? null : _loadConfigs,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: isWide ? _buildDesktopLayout() : _buildCompactLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: _buildConnectionPanel(),
          ),
        ),
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildServerListPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildConnectionPanel(),
          const SizedBox(height: 24),
          SizedBox(
            height: 420,
            child: _buildServerListPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionPanel() {
    final statusText = switch (_connectionState) {
      VpnConnectionState.connected => 'متصل شد',
      VpnConnectionState.connecting => 'در حال اتصال...',
      VpnConnectionState.disconnected => 'قطع است',
    };

    final statusColor = switch (_connectionState) {
      VpnConnectionState.connected => const Color(0xFF10B981),
      VpnConnectionState.connecting => const Color(0xFFF59E0B),
      VpnConnectionState.disconnected => const Color(0xFF94A3B8),
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (_connectionState == VpnConnectionState.connected) ...[
                const SizedBox(width: 10),
                Text(
                  _duration,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        AnimatedConnectButton(
          state: _connectionState,
          onTap: _toggleConnection,
        ),
        const SizedBox(height: 20),
        Text(
          _selectedConfig?.title ?? 'سروری انتخاب نشده است',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (_selectedConfig != null) ...[
          const SizedBox(height: 4),
          Text(
            _selectedConfig!.serverDisplay,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
        const SizedBox(height: 28),
        StatsCard(
          downloadSpeed: _downloadSpeed,
          uploadSpeed: _uploadSpeed,
          totalDownload: _totalDownload,
          totalUpload: _totalUpload,
        ),
      ],
    );
  }

  Widget _buildServerListPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'سرورها (${_configs.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'virasub.ir',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoadingConfigs
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded, size: 42, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _loadConfigs,
                            icon: const Icon(Icons.refresh),
                            label: const Text('تلاش مجدد'),
                          ),
                        ],
                      ),
                    )
                  : _configs.isEmpty
                      ? const Center(child: Text('هیچ کانفیگی یافت نشد'))
                      : ListView.separated(
                          itemCount: _configs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final config = _configs[index];
                            final isSelected = _selectedConfig?.id == config.id;
                            return ConfigTile(
                              config: config,
                              isSelected: isSelected,
                              onTap: () async {
                                setState(() => _selectedConfig = config);
                                if (_connectionState == VpnConnectionState.connected) {
                                  await _vpnService.disconnect();
                                  await _vpnService.connect(config);
                                }
                              },
                              onPingTap: () => _pingSingleConfig(config),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
