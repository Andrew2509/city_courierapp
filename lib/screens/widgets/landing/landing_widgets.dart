import 'package:flutter/material.dart';

class LandingSocialButton extends StatelessWidget {
  final String label;
  final bool isGoogle;
  final VoidCallback? onTap;

  const LandingSocialButton({
    super.key,
    required this.label,
    required this.isGoogle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: isGoogle ? Colors.white : const Color(0xFFF97316),
          borderRadius: BorderRadius.circular(16),
          border: isGoogle ? Border.all(color: const Color(0xFFE5E7EB)) : null,
          boxShadow: isGoogle
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFFF97316).withValues(alpha: 0.2),
                    offset: const Offset(0, 8),
                    blurRadius: 15,
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isGoogle)
              Image.network(
                'https://developers.google.com/identity/images/g-logo.png',
                height: 24,
                width: 24,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.account_circle, color: Colors.blue),
              )
            else
              const Icon(Icons.smartphone, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isGoogle ? const Color(0xFF374151) : Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LandingActionBox extends StatelessWidget {
  final String? assetPath;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const LandingActionBox({
    super.key,
    this.assetPath,
    required this.label,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF3F4F6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: assetPath != null
                  ? Image.asset(assetPath!, width: 24, height: 24)
                  : Icon(
                      icon,
                      color: const Color(0xFF374151),
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}

class LandingInputField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboardType;

  final Widget? suffix;

  const LandingInputField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
              prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LandingPrimaryButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const LandingPrimaryButton({
    super.key,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF97316),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withValues(alpha: 0.15),
              offset: const Offset(0, 8),
              blurRadius: 15,
            ),
          ],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
