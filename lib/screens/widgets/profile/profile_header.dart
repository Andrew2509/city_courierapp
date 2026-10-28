import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/profile/profile_screen.dart';

class ProfileHeader extends StatefulWidget {
  final Color primaryColor;
  final Map<String, dynamic>? userData;
  final bool isLoading;
  final VoidCallback? onEditProfile;
  final bool initialCourierMode;

  const ProfileHeader({
    super.key,
    required this.primaryColor,
    this.userData,
    this.isLoading = false,
    this.onEditProfile,
    this.initialCourierMode = false,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  late bool _isCourierMode;

  @override
  void initState() {
    super.initState();
    _isCourierMode = widget.initialCourierMode;
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.userData?['name'] ?? 'City Courier User';
    final String phone = widget.userData?['phone'] ?? '+62 812-3456-7890';
    String? photoUrl = widget.userData?['photo_url'];

    // Format photoUrl: Google URLs start with 'http',
    // uploaded photos might be relative paths (e.g., '/storage/...')
    if (photoUrl != null && !photoUrl.startsWith('http')) {
      // Prepend base domain and storage path if it's a relative path
      // Ensure there's a leading slash if not present
      final String cleanPath = photoUrl.startsWith('/') ? photoUrl : '/$photoUrl';
      photoUrl = 'https://citycourier.pabm.space/storage$cleanPath';
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 16,
        24,
        24, // spacing below the card
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Text and Icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profil Saya',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kelola akun dan pengaturan Anda',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications_none_rounded, color: isDarkMode ? Colors.white : const Color(0xFF1E293B)),
                        onPressed: () {},
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: const Text(
                            '2',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: isDarkMode ? Colors.white : const Color(0xFF1E293B)),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Container(
            width: double.infinity,
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/Bg.png'),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background Image
            Positioned(
              right: -30,
              bottom: 0,
              width: 360, // Increased size and shifted right
              child: Image.asset(
                'assets/images/Kurir1.png',
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomRight,
              ),
            ),
            
            // Card Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Section: Avatar and User Details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              image: photoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        photoUrl.startsWith('http')
                                            ? photoUrl
                                            : 'https://citycourier.pabm.space/storage/$photoUrl',
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: photoUrl == null
                                ? const Icon(
                                    Icons.person,
                                    color: Color(0xFFE0E0E0),
                                    size: 52,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Color(0xFF111827),
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.isLoading)
                              Container(
                                width: 150,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )
                            else
                              Text(
                                name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16, // Reduced from 18
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 2),
                            if (widget.isLoading)
                              Container(
                                width: 120,
                                height: 16,
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              )
                            else
                              Text(
                                phone,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12, // Reduced from 13
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20), // Space to show the courier background illustration
                  
                  // Bottom Section: Mode Switch
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                                    builder: (context) => const ProfileScreen(),
                                  ),
                                  (route) => false,
                                );
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isCourierMode
                                    ? widget.primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: !_isCourierMode
                                    ? [
                                        BoxShadow(
                                          color: widget.primaryColor.withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    color: !_isCourierMode ? Colors.white : const Color(0xFF9CA3AF),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Akun Personal',
                                    style: TextStyle(
                                      color: !_isCourierMode ? Colors.white : const Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
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
                                            fromPersonalProfile: true),
                                  ),
                                ).then((_) {
                                  if (mounted) setState(() => _isCourierMode = false);
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isCourierMode
                                    ? widget.primaryColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: _isCourierMode
                                    ? [
                                        BoxShadow(
                                          color: widget.primaryColor.withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.work_outline,
                                    color: _isCourierMode ? Colors.white : const Color(0xFF9CA3AF),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Akun Kurir',
                                    style: TextStyle(
                                      color: _isCourierMode ? Colors.white : const Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ), // closing Stack
      ), // closing Container
      ], // closing Column children
    ), // closing Column
    ); // closing Padding
  }
}
