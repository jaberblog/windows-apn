import 'package:flutter/material.dart';
import '../models/vpn_config.dart';

class ConfigTile extends StatelessWidget {
  final VpnConfig config;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onPingTap;

  const ConfigTile({
    super.key,
    required this.config,
    required this.isSelected,
    required this.onTap,
    required this.onPingTap,
  });

  Color _pingColor(int? ping) {
    if (ping == null || ping <= 0) return const Color(0xFF64748B);
    if (ping < 180) return const Color(0xFF10B981);
    if (ping < 380) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final pingColor = _pingColor(config.pingMs);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF17233B) : const Color(0xFF131A2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    config.serverDisplay,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: config.isPinging ? null : onPingTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pingColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: pingColor.withOpacity(0.35)),
                ),
                child: config.isPinging
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: pingColor,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.network_ping_rounded, size: 14, color: pingColor),
                          const SizedBox(width: 5),
                          Text(
                            config.pingMs != null ? '${config.pingMs} ms' : 'پینگ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: pingColor,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (config.iconUrl != null && config.iconUrl!.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          config.iconUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultIconBox(),
        ),
      );
    }
    return _defaultIconBox();
  }

  Widget _defaultIconBox() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF38BDF8).withOpacity(0.2)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.dns_rounded,
        color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
        size: 20,
      ),
    );
  }
}
