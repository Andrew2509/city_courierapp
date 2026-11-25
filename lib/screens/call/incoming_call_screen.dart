import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:city_courierapp/models/call/call_models.dart';
import 'package:city_courierapp/providers/call_provider.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primaryOrange = Color(0xFFEC5B13);
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CallProvider>();
    final CallSessionModel? call = provider.currentCall;
    final participant = call?.counterpartyForUser(provider.currentUserId);
    final callerName = participant?.name ?? 'Pengguna City Courier';
    final roleLabel = participant?.roleDisplay ?? 'Peserta Pengiriman';
    final orderText = call?.orderNumber != null ? 'Pesanan #${call!.orderNumber}' : 'City Courier';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryOrange.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primaryOrange.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_in_talk_rounded, size: 15, color: _primaryOrange),
                      SizedBox(width: 6),
                      Text(
                        'Panggilan Suara Masuk',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) {
                    final scale = 1.0 + (_pulseController.value * 0.08);
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.55),
                        width: 3,
                      ),
                    ),
                    child: _CallAvatar(
                      name: callerName,
                      avatarUrl: participant?.avatar,
                      radius: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  callerName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$roleLabel • $orderText',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  provider.phaseLabel,
                  style: const TextStyle(
                    color: Color(0xFF86EFAC),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _IncomingActionButton(
                      label: 'Tolak',
                      icon: Icons.call_end_rounded,
                      color: const Color(0xFFDC2626),
                      onTap: () => unawaited(provider.rejectIncomingCall()),
                    ),
                    _IncomingActionButton(
                      label: 'Terima',
                      icon: Icons.call_rounded,
                      color: const Color(0xFF16A34A),
                      onTap: () => unawaited(provider.acceptIncomingCall()),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IncomingActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IncomingActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;

  const _CallAvatar({
    required this.name,
    this.avatarUrl,
    this.radius = 52,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';
    final cleanUrl = avatarUrl?.trim();
    if (cleanUrl != null && cleanUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF1E293B),
        foregroundImage: NetworkImage(cleanUrl),
        onForegroundImageError: (_, _) {},
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.65,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEC5B13).withValues(alpha: 0.25),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.65,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
