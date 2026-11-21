import 'package:flutter/material.dart';

/// The mart2door "M2D" logo artwork (maroon letters with a gold 2), as a
/// transparent image so it can sit on any light background.
///
/// Kept identical in the customer app, the delivery app and the admin web.
class M2dMark extends StatelessWidget {
  const M2dMark({super.key, required this.width});

  static const _asset = 'assets/brand/m2d_logo.png';

  /// Width over height of the artwork.
  static const double aspectRatio = 1131 / 499;

  /// Width of the logo; the height follows from its proportions.
  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset,
      width: width,
      height: width / aspectRatio,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'mart2door',
    );
  }
}
