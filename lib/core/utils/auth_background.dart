import 'dart:math';

class AuthBackground {
  static const List<String> _backgrounds = [
    'assets/images/auth_bg_1.jpg',
    'assets/images/auth_bg_2.jpg',
    'assets/images/auth_bg_3.jpg',
    'assets/images/auth_bg_4.jpg',
  ];

  static String getBackground() {
    if (_backgrounds.isEmpty) {
      return 'assets/images/auth_bg_1.jpg';
    }

    final random = Random();
    return _backgrounds[random.nextInt(_backgrounds.length)];
  }
}