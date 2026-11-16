import 'package:flutter/material.dart';

class RanaLogo extends StatelessWidget {
  final double size;
  const RanaLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
}
