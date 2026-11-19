import 'package:flutter/material.dart';

class StatsCard extends StatelessWidget {
  final int downloadSpeed;
  final int uploadSpeed;
  final int totalDownload;
  final int totalUpload;

  const StatsCard({
    super.key,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.totalDownload,
    required this.totalUpload,
  });

  static String formatBytes(int bytes, {bool perSecond = false}) {
    if (bytes <= 0) return perSecond ? '0 B/s' : '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final formatted = value >= 100
        ? value.toStringAsFixed(0)
        : value >= 10
            ? value.toStringAsFixed(1)
            : value.toStringAsFixed(2);

    return '$formatted ${units[unitIndex]}${perSecond ? '/s' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  icon: Icons.arrow_downward_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'سرعت دانلود',
                  value: formatBytes(downloadSpeed, perSecond: true),
                ),
              ),
              Container(width: 1, height: 38, color: const Color(0xFF1E293B)),
              Expanded(
                child: _MetricItem(
                  icon: Icons.arrow_upward_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  label: 'سرعت آپلود',
                  value: formatBytes(uploadSpeed, perSecond: true),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFF1E293B)),
          ),
          Row(
            children: [
              Expanded(
                child: _MetricItem(
                  icon: Icons.downloading_rounded,
                  iconColor: const Color(0xFF34D399),
                  label: 'حجم دانلود',
                  value: formatBytes(totalDownload),
                ),
              ),
              Container(width: 1, height: 38, color: const Color(0xFF1E293B)),
              Expanded(
                child: _MetricItem(
                  icon: Icons.upload_rounded,
                  iconColor: const Color(0xFF60A5FA),
                  label: 'حجم آپلود',
                  value: formatBytes(totalUpload),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _MetricItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
