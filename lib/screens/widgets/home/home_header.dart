import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final Map<String, dynamic>? userData;
  const HomeHeader({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 48, left: 20, right: 20, bottom: 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 255, 255, 255),
            Color(0xFFEC5B13),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(48)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            right: -40,
            top: 0,
            bottom: 0,
            child: Center(
              child: Image.asset(
                'assets/images/Logo Troli Box 1.png',
                width: 180,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/Logo City Courie.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              if (userData != null &&
                  (userData!['name'] as String?)?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 15),
                const Text(
                  'Selamat Datang',
                  style: TextStyle(color: Colors.black, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  (userData!['name'] as String).trim(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
