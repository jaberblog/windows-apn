import 'package:flutter/material.dart';
import '../services/vpn_service.dart';

class AnimatedConnectButton extends StatefulWidget {
  final VpnConnectionState state;
  final VoidCallback onTap;

  const AnimatedConnectButton({
    super.key,
    required this.state,
    required this.onTap,
  });

  @override
  State<AnimatedConnectButton> createState() => _AnimatedConnectButtonState();
}

class _AnimatedConnectButtonState extends State<AnimatedConnectButton>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _spinController;
  late final AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.state == VpnConnectionState.connected;
    final isConnecting = widget.state == VpnConnectionState.connecting;

    final primaryColor = isConnected
        ? const Color(0xFF10B981)
        : isConnecting
            ? const Color(0xFFF59E0B)
            : const Color(0xFF38BDF8);

    final secondaryColor = isConnected
        ? const Color(0xFF059669)
        : isConnecting
            ? const Color(0xFFD97706)
            : const Color(0xFF2563EB);

    return GestureDetector(
      onTapDown: (_) => _pressController.reverse(),
      onTapUp: (_) {
        _pressController.forward();
        widget.onTap();
      },
      onTapCancel: () => _pressController.forward(),
      child: ScaleTransition(
        scale: _pressController,
        child: SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isConnected || isConnecting)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [0.0, 0.5].map((delay) {
                        final progress = (_pulseController.value + delay) % 1.0;
                        final size = 130 + (progress * 60);
                        final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.35;
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withOpacity(opacity),
                              width: 2.5,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              if (isConnecting)
                RotationTransition(
                  turns: _spinController,
                  child: Container(
                    width: 146,
                    height: 146,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          primaryColor.withOpacity(0.0),
                          primaryColor,
                        ],
                      ),
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryColor, secondaryColor],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.45),
                      blurRadius: isConnected ? 28 : 16,
                      spreadRadius: isConnected ? 4 : 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.power_settings_new_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isConnected
                          ? 'قطع اتصال'
                          : isConnecting
                              ? 'صبر کنید'
                              : 'اتصال',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
