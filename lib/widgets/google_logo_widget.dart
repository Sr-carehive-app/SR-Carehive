import 'package:flutter/material.dart';

class GoogleLogoWidget extends StatelessWidget {
  final double size;
  
  const GoogleLogoWidget({Key? key, this.size = 24}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: Center(
            child: Text(
              'G',
              style: TextStyle(
                fontSize: size * 0.6,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4285F4),
              ),
            ),
          ),
        );
      },
    );
  }
}
