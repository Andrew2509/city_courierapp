import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/widgets/landing/orange_header_painter.dart';
import 'package:city_courierapp/screens/widgets/landing/welcome_view.dart';
import 'package:city_courierapp/screens/widgets/landing/login_view.dart';

enum _LandingViewType { welcome, login }

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  _LandingViewType _viewType = _LandingViewType.welcome;

  void _switchToLogin() {
    setState(() => _viewType = _LandingViewType.login);
  }

  void _switchToWelcome() {
    setState(() => _viewType = _LandingViewType.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            CustomPaint(
              size: Size(size.width, size.height * 0.5),
              painter: OrangeHeaderPainter(),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Header Section (Logo + Hero)
                  Stack(
                    children: [
                      // Space for padding
                      const SizedBox(height: 330, width: double.infinity),

                      // Logo
                      Positioned(
                        top: 10,
                        left: 24,
                        right: 24,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Image.asset(
                            'assets/images/Logo City Courie.png',
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // Hero Image (Van)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          height: 480,
                          child: Image.asset(
                            'assets/images/image.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.airport_shuttle,
                                  size: 100,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                      ),

                      // Close / Back button if opened as a pushed route
                      if (Navigator.canPop(context))
                        Positioned(
                          top: 14,
                          right: 20,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Tagline Image
                  if (_viewType == _LandingViewType.welcome)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Image.asset(
                        'assets/images/Typhography Slogan.png',
                        height: 85,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(),
                      ),
                    ),

                  // Spacer to push content down or position it
                  SizedBox(
                    height: _viewType == _LandingViewType.welcome ? 20 : 0,
                  ),

                  // Interactive Section
                  _viewType == _LandingViewType.welcome
                      ? WelcomeView(
                          key: const ValueKey('welcome'),
                          onPhoneLoginTap: _switchToLogin,
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 20, bottom: 40),
                          child: LoginView(
                            key: const ValueKey('login'),
                            onBackToLanding: _switchToWelcome,
                          ),
                        ),

                  // Small bottom padding for safety
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
