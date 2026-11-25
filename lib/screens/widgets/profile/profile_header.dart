import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/profile/profile_screen.dart';
import 'package:city_courierapp/widgets/common/city_courier_icon.dart';
import 'package:flutter/material.dart';

class ProfileHeader extends StatefulWidget {
  final Color primaryColor;
  final Map<String, dynamic>? userData;
  final bool isLoading;
  final VoidCallback? onEditProfile;
  final bool initialCourierMode;

  /// True hanya untuk pengguna yang sudah resmi terdaftar dan terverifikasi
  /// sebagai kurir. Selama belum, pilihan "Akun Kurir" tidak ditampilkan.
  final bool isCourier;

  const ProfileHeader({
    super.key,
    required this.primaryColor,
    this.userData,
    this.isLoading = false,
    this.onEditProfile,
    this.initialCourierMode = false,
    this.isCourier = false,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  late bool _isCourierMode;

  @override
  void initState() {
    super.initState();
    _isCourierMode = widget.initialCourierMode && widget.isCourier;
  }

  String _maskPhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length < 7) return trimmed;
    final prefix = trimmed.substring(0, 4);
    final suffix = trimmed.substring(trimmed.length - 2);
    return '$prefix••••••••$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.userData?['name'] ?? 'City Courier User';
    final String rawPhone = widget.userData?['phone'] ?? '+62 812-3456-7890';
    final String phone = _maskPhone(rawPhone);
    String? photoUrl = widget.userData?['photo_url'];

    // Format photoUrl: Google URLs start with 'http',
    // uploaded photos might be relative paths (e.g., '/storage/...')
    if (photoUrl != null && !photoUrl.startsWith('http')) {
      final String cleanPath =
          photoUrl.startsWith('/') ? photoUrl : '/$photoUrl';
      photoUrl = 'https://www.neonflux.my.id/storage$cleanPath';
    }

    final double topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF7A26),
            widget.primaryColor,
            const Color(0xFFE04908),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _HeaderWavePainter(),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              topInset + (widget.isCourier ? 14 : 24),
              20,
              22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isCourier) ...[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 268),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (!_isCourierMode) return;
                                  setState(() => _isCourierMode = false);
                                  if (widget.initialCourierMode) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ProfileScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_isCourierMode
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(100),
                                    boxShadow: !_isCourierMode
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : const [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Akun Personal',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: !_isCourierMode
                                            ? widget.primaryColor
                                            : Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_isCourierMode) return;
                                  setState(() => _isCourierMode = true);
                                  if (!widget.initialCourierMode) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const DriverProfileScreen(
                                          fromPersonalProfile: true,
                                        ),
                                      ),
                                    ).then((_) {
                                      if (mounted) {
                                        setState(() => _isCourierMode = false);
                                      }
                                    });
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isCourierMode
                                        ? Colors.white
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(100),
                                    boxShadow: _isCourierMode
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : const [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Akun Kurir',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: _isCourierMode
                                            ? widget.primaryColor
                                            : Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: widget.onEditProfile,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: photoUrl != null
                                  ? Image.network(
                                      photoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: CityCourierCustomIcon(
                                          CourierIconKind.avatarUser,
                                          size: 52,
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: CityCourierCustomIcon(
                                        CourierIconKind.avatarUser,
                                        size: 52,
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: -1,
                            right: -1,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: CityCourierCustomIcon(
                                  CourierIconKind.cameraEdit,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.isLoading) ...[
                            Container(
                              width: 165,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.24),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 118,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ] else ...[
                            Text(
                              name,
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              phone,
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderWavePainter extends CustomPainter {
  const _HeaderWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lightWave = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final darkWave = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.18,
        size.width * 0.56,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.72,
        size.width,
        size.height * 0.34,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final path2 = Path()
      ..moveTo(0, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.88,
        size.width * 0.68,
        size.height * 0.54,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.36,
        size.width,
        size.height * 0.56,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path1, lightWave);
    canvas.drawPath(path2, darkWave);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
