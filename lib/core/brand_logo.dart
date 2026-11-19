import 'package:flutter/material.dart';

import 'm2d_mark.dart';
import 'theme.dart';

/// mart2door logo: the "m2d" mark on a white tile, with the wordmark.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 88, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: M2dMark(width: size * 0.7),
        ),
        if (showWordmark) ...[
          SizedBox(height: size * 0.2),
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
              children: const [
                TextSpan(text: 'mart'),
                TextSpan(
                  text: '2',
                  style: TextStyle(color: AppColors.accent),
                ),
                TextSpan(text: 'door'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
