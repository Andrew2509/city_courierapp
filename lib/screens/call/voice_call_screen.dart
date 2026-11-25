import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:city_courierapp/providers/call_provider.dart';

class VoiceCallScreen extends StatelessWidget {
  const VoiceCallScreen({super.key});

  static const Color _primaryOrange = Color(0xFFEC5B13);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CallProvider>();
    final call = provider.currentCall;
    final counterparty = call?.counterpartyForUser(provider.currentUserId);
    final displayName = counterparty?.name ?? 'Pengguna City Courier';
    final roleText = counterparty?.roleDisplay ?? 'Panggilan Suara';
    final orderText = call?.orderNumber != null ? 'Order #${call!.orderNumber}' : 'Panggilan Dalam Aplikasi';
    final phase = provider.phase;

    final Color statusColor = switch (phase) {
      VoiceCallUiPhase.connected => const Color(0xFF86EFAC),
      VoiceCallUiPhase.failed => const Color(0xFFFCA5A5),
      VoiceCallUiPhase.ended => const Color(0xFF94A3B8),
      _ => const Color(0xFFFED7AA),
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Kembali ke chat',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text(
          'Panggilan Suara',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  orderText,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (phase == VoiceCallUiPhase.connected
                            ? const Color(0xFF22C55E)
                            : _primaryOrange)
                        .withValues(alpha: 0.55),
                    width: 2.5,
                  ),
                ),
                child: _ProfilePhotoAvatar(
                  name: displayName,
                  avatarUrl: counterparty?.avatar,
                  radius: 56,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                roleText,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              ),
              const SizedBox(height: 16),
              Text(
                provider.phaseLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                phase == VoiceCallUiPhase.connected ? provider.formattedDuration : '00:00',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (provider.errorMessage != null && phase == VoiceCallUiPhase.failed) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F1D1D).withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFFEE2E2), fontSize: 12.5),
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallControlButton(
                      icon: provider.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: provider.isMuted ? 'Dibisukan' : 'Mikrofon',
                      active: provider.isMuted,
                      onTap: () => unawaited(provider.toggleMute()),
                    ),
                    _CallControlButton(
                      icon: Icons.call_end_rounded,
                      label: 'Akhiri',
                      backgroundColor: const Color(0xFFDC2626),
                      iconColor: Colors.white,
                      size: 64,
                      onTap: () => unawaited(provider.endCall()),
                    ),
                    _CallControlButton(
                      icon: provider.isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
                      label: 'Speaker',
                      active: provider.isSpeakerOn,
                      onTap: () => unawaited(provider.toggleSpeaker()),
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

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final VoidCallback onTap;

  const _CallControlButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.backgroundColor,
    this.iconColor,
    this.size = 54,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? (active ? Colors.white : Colors.white.withValues(alpha: 0.14));
    final fg = iconColor ?? (active ? const Color(0xFF0F172A) : Colors.white);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: bg,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, color: fg, size: size * 0.48),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePhotoAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;

  const _ProfilePhotoAvatar({
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
