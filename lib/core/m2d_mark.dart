import 'package:flutter/material.dart';

/// The mart2door "m2d" mark, drawn from outlines so it is sharp at any
/// size and needs no image or font file. The letters match the app icon.
///
/// This file is generated from the brand artwork and kept identical in the
/// customer app, the delivery app and the admin web.
class M2dMark extends StatelessWidget {
  const M2dMark({
    super.key,
    required this.width,
    this.letterColor = const Color(0xFF800020),
    this.accentColor = const Color(0xFFFF8A1F),
  });

  /// Width of the mark; the height follows from its proportions.
  final double width;

  /// Colour of the "m" and the "d".
  final Color letterColor;

  /// Colour of the "2".
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'mart2door',
      image: true,
      child: CustomPaint(
        size: Size(width, width * _M2dPainter.height / _M2dPainter.width),
        painter: _M2dPainter(letterColor, accentColor),
      ),
    );
  }
}

class _M2dPainter extends CustomPainter {
  _M2dPainter(this.letterColor, this.accentColor);

  final Color letterColor;
  final Color accentColor;

  /// Size of the artwork the outlines below are measured in.
  static const double width = 2115;
  static const double height = 754;

  /// 'm'
  static final Path _m = Path()
    ..moveTo(939, 420)
    ..lineTo(939, 746)
    ..lineTo(769, 746)
    ..lineTo(769, 443)
    ..quadraticBezierTo(769, 389, 740.5, 359.5)
    ..quadraticBezierTo(712, 330, 662, 330)
    ..quadraticBezierTo(612, 330, 583.5, 359.5)
    ..quadraticBezierTo(555, 389, 555, 443)
    ..lineTo(555, 746)
    ..lineTo(385, 746)
    ..lineTo(385, 443)
    ..quadraticBezierTo(385, 389, 356.5, 359.5)
    ..quadraticBezierTo(328, 330, 278, 330)
    ..quadraticBezierTo(228, 330, 199.5, 359.5)
    ..quadraticBezierTo(171, 389, 171, 443)
    ..lineTo(171, 746)
    ..lineTo(0, 746)
    ..lineTo(0, 188)
    ..lineTo(171, 188)
    ..lineTo(171, 258)
    ..quadraticBezierTo(197, 223, 239, 202.5)
    ..quadraticBezierTo(281, 182, 334, 182)
    ..quadraticBezierTo(397, 182, 446.5, 209)
    ..quadraticBezierTo(496, 236, 524, 286)
    ..quadraticBezierTo(553, 240, 603, 211)
    ..quadraticBezierTo(653, 182, 712, 182)
    ..quadraticBezierTo(816, 182, 877.5, 245)
    ..quadraticBezierTo(939, 308, 939, 420)
    ..close();

  /// '2'
  static final Path _two = Path()
    ..moveTo(1032, 584)
    ..quadraticBezierTo(1130, 503, 1186.5, 451)
    ..quadraticBezierTo(1243, 399, 1282, 342)
    ..quadraticBezierTo(1321, 285, 1321, 231)
    ..quadraticBezierTo(1321, 190, 1302, 167)
    ..quadraticBezierTo(1283, 144, 1245, 144)
    ..quadraticBezierTo(1207, 144, 1185.5, 172.5)
    ..quadraticBezierTo(1164, 201, 1164, 253)
    ..lineTo(999, 253)
    ..quadraticBezierTo(1001, 168, 1035.5, 111)
    ..quadraticBezierTo(1070, 54, 1126.5, 27)
    ..quadraticBezierTo(1183, 0, 1252, 0)
    ..quadraticBezierTo(1371, 0, 1431.5, 61)
    ..quadraticBezierTo(1492, 122, 1492, 220)
    ..quadraticBezierTo(1492, 327, 1419, 418.5)
    ..quadraticBezierTo(1346, 510, 1233, 597)
    ..lineTo(1503, 597)
    ..lineTo(1503, 736)
    ..lineTo(1001, 736)
    ..lineTo(1001, 609)
    ..quadraticBezierTo(1035, 582, 1032, 584)
    ..close();

  /// 'd'
  static final Path _d = Path()
    ..moveTo(1772, 180)
    ..quadraticBezierTo(1827, 180, 1872.5, 203)
    ..quadraticBezierTo(1918, 226, 1944, 265)
    ..lineTo(1944, 6)
    ..lineTo(2115, 6)
    ..lineTo(2115, 746)
    ..lineTo(1944, 746)
    ..lineTo(1944, 666)
    ..quadraticBezierTo(1920, 706, 1875.5, 730)
    ..quadraticBezierTo(1831, 754, 1772, 754)
    ..quadraticBezierTo(1703, 754, 1647, 718.5)
    ..quadraticBezierTo(1591, 683, 1558.5, 617.5)
    ..quadraticBezierTo(1526, 552, 1526, 466)
    ..quadraticBezierTo(1526, 380, 1558.5, 315)
    ..quadraticBezierTo(1591, 250, 1647, 215)
    ..quadraticBezierTo(1703, 180, 1772, 180)
    ..close()
    ..moveTo(1822, 329)
    ..quadraticBezierTo(1771, 329, 1735.5, 365.5)
    ..quadraticBezierTo(1700, 402, 1700, 466)
    ..quadraticBezierTo(1700, 530, 1735.5, 567.5)
    ..quadraticBezierTo(1771, 605, 1822, 605)
    ..quadraticBezierTo(1873, 605, 1908.5, 568)
    ..quadraticBezierTo(1944, 531, 1944, 467)
    ..quadraticBezierTo(1944, 403, 1908.5, 366)
    ..quadraticBezierTo(1873, 329, 1822, 329)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final letters = Paint()..color = letterColor;
    final accent = Paint()..color = accentColor;
    canvas
      ..save()
      ..scale(size.width / width, size.height / height)
      ..drawPath(_m, letters)
      ..drawPath(_two, accent)
      ..drawPath(_d, letters)
      ..restore();
  }

  @override
  bool shouldRepaint(_M2dPainter old) =>
      old.letterColor != letterColor || old.accentColor != accentColor;
}
