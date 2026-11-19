import 'dart:ffi';
import 'dart:io';

typedef _InternetSetOptionNative = Int32 Function(
  IntPtr hInternet,
  Uint32 dwOption,
  Pointer<Void> lpBuffer,
  Uint32 dwBufferLength,
);
typedef _InternetSetOptionDart = int Function(
  int hInternet,
  int dwOption,
  Pointer<Void> lpBuffer,
  int dwBufferLength,
);

class WindowsProxyService {
  static const String _regPath =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  /// Enables Windows System Proxy pointing to local Xray HTTP inbound
  static Future<void> enableProxy({
    String host = '127.0.0.1',
    int port = 10809,
  }) async {
    if (!Platform.isWindows) return;

    await Process.run('reg', [
      'add',
      _regPath,
      '/v',
      'ProxyEnable',
      '/t',
      'REG_DWORD',
      '/d',
      '1',
      '/f',
    ]);

    await Process.run('reg', [
      'add',
      _regPath,
      '/v',
      'ProxyServer',
      '/t',
      'REG_SZ',
      '/d',
      '$host:$port',
      '/f',
    ]);

    await Process.run('reg', [
      'add',
      _regPath,
      '/v',
      'ProxyOverride',
      '/t',
      'REG_SZ',
      '/d',
      'localhost;127.*;10.*;172.16.*;172.31.*;192.168.*;<local>',
      '/f',
    ]);

    _notifySystemProxyChanged();
  }

  /// Disables Windows System Proxy cleanly
  static Future<void> disableProxy() async {
    if (!Platform.isWindows) return;

    await Process.run('reg', [
      'add',
      _regPath,
      '/v',
      'ProxyEnable',
      '/t',
      'REG_DWORD',
      '/d',
      '0',
      '/f',
    ]);

    _notifySystemProxyChanged();
  }

  /// Calls WinINet InternetSetOptionW so browsers and apps apply proxy changes immediately
  static void _notifySystemProxyChanged() {
    try {
      final wininet = DynamicLibrary.open('wininet.dll');
      final internetSetOption = wininet.lookupFunction<_InternetSetOptionNative, _InternetSetOptionDart>(
        'InternetSetOptionW',
      );
      // INTERNET_OPTION_SETTINGS_CHANGED = 39, INTERNET_OPTION_REFRESH = 37
      internetSetOption(0, 39, nullptr, 0);
      internetSetOption(0, 37, nullptr, 0);
    } catch (_) {
      // Registry update already succeeded even if WinINet notification fails
    }
  }
}
