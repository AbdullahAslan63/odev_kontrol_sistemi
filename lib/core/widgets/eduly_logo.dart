import 'package:flutter/material.dart';

/// Eduly Uygulama Logosu ve Amblem Widget'ı
class EdulyLogo extends StatelessWidget {
  const EdulyLogo({
    super.key,
    this.size = 80,
    this.useImageAsset = true,
  });

  final double size;
  final bool useImageAsset;

  @override
  Widget build(BuildContext context) {
    if (useImageAsset) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withAlpha(40),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/eduly_app_icon_1024.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _FallbackEmblem(size: size);
            },
          ),
        ),
      );
    }

    return _FallbackEmblem(size: size);
  }
}

class _FallbackEmblem extends StatelessWidget {
  const _FallbackEmblem({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1E1B4B),
      ),
      child: Icon(
        Icons.school_rounded,
        size: size * 0.52,
        color: Colors.white,
      ),
    );
  }
}
