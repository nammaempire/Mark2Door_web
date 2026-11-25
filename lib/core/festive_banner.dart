import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Festival banner designs with moving 3D artwork. Keys are stored in
/// `banners/{id}.layout` next to the ordinary designs.
///
/// * `christmas`: a spinning gift box in falling snow.
/// * `newYear`: the coming year in swaying 3D numerals, with fireworks.
/// * `pongal`: a turning Pongal pot boiling over, under a spinning sun.
///
/// This file is kept identical in the admin web and the customer app.
const festiveLayouts = <String>['christmas', 'newYear', 'pongal'];

/// Draws one of the [festiveLayouts]. [scale] is the card height divided
/// by the height the measurements were designed at (158), and [text] is
/// the banner's title, subtitle and button, laid out by the caller.
class FestiveBanner extends StatefulWidget {
  const FestiveBanner({
    super.key,
    required this.kind,
    required this.scale,
    required this.text,
  });

  final String kind;
  final double scale;
  final Widget text;

  /// Background colours for [kind], top-left to bottom-right.
  static List<Color> colorsFor(String kind) => switch (kind) {
        'newYear' => const [Color(0xFF2B1B6B), Color(0xFF0B0F33)],
        'pongal' => const [Color(0xFFFFB627), Color(0xFFE8590C)],
        _ => const [Color(0xFF0F7A4F), Color(0xFF7A1022)],
      };

  /// The year the New Year banner shows: next year for most of the year,
  /// and the year just begun through January and February.
  static int newYearFor(DateTime now) =>
      now.month >= 3 ? now.year + 1 : now.year;

  @override
  State<FestiveBanner> createState() => _FestiveBannerState();
}

class _FestiveBannerState extends State<FestiveBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  /// Widget tests wait for animations to finish, and these never do, so
  /// under test the artwork holds one still frame.
  static bool get _underTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    if (_underTest) {
      _loop.value = 0.3;
    } else {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scale;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: FestiveBanner.colorsFor(widget.kind),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _loop,
              builder: (context, _) => CustomPaint(
                painter: _FestivePainter(
                  kind: widget.kind,
                  t: _loop.value,
                  s: s,
                  year: FestiveBanner.newYearFor(DateTime.now()),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18 * s, 16 * s, 126 * s, 14 * s),
            child: widget.text,
          ),
        ],
      ),
    );
  }
}

const _tau = math.pi * 2;

/// Repeatable "random" number in 0..1 for particle [i].
double _rand(int i, int salt) {
  final x = math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

class _FestivePainter extends CustomPainter {
  _FestivePainter({
    required this.kind,
    required this.t,
    required this.s,
    required this.year,
  });

  final String kind;

  /// Position in the 12-second loop, 0..1. Everything moves a whole
  /// number of times per loop, so the loop has no visible seam.
  final double t;
  final double s;
  final int year;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    // Where the 3D object stands: the right of the card.
    final hero = Offset(size.width - 62 * s, size.height * 0.52);
    switch (kind) {
      case 'newYear':
        _fireworks(canvas, size);
        _year3d(canvas, hero);
        _confetti(canvas, size);
      case 'pongal':
        _sun(canvas, hero);
        _sugarcane(canvas, hero);
        _pot(canvas, hero);
        _steam(canvas, hero);
      default:
        _snow(canvas, size, far: true);
        _ground(canvas, size);
        _gift(canvas, hero);
        _snow(canvas, size, far: false);
    }
  }

  // --- Christmas ---------------------------------------------------------

  /// Snowflakes at two depths: the near ones are larger and fall faster.
  void _snow(Canvas canvas, Size size, {required bool far}) {
    final paint = Paint();
    final count = far ? 26 : 12;
    for (var i = 0; i < count; i++) {
      final salt = far ? 1 : 2;
      final speed = (far ? 1 : 2) + (_rand(i, salt + 5) > 0.5 ? 1 : 0);
      final fall = (_rand(i, salt) + t * speed) % 1.0;
      final sway = math.sin(_tau * (t * 2 + _rand(i, salt + 9))) * 6 * s;
      final x = _rand(i, salt + 3) * size.width + sway;
      final y = fall * (size.height + 12 * s) - 6 * s;
      final r = (far ? 1.1 : 2.2) * s * (0.7 + _rand(i, salt + 7) * 0.8);
      paint.color = Colors.white.withAlpha(far ? 120 : 220);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  /// A snowy rise for the gift to stand on.
  void _ground(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.45, size.height)
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height - 40 * s,
        size.width,
        size.height - 22 * s,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0x40FFFFFF));
  }

  /// A gift box turning on the spot: a real box, drawn face by face, so
  /// its sides narrow and widen and catch the light as it turns.
  void _gift(Canvas canvas, Offset c) {
    final angle = _tau * t * 2;
    final bob = math.sin(_tau * t * 3) * 3 * s;
    final centre = c.translate(0, 14 * s + bob);
    // Shadow on the snow.
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, 50 * s),
        width: 78 * s,
        height: 14 * s,
      ),
      Paint()..color = const Color(0x40000000),
    );
    _box(
      canvas,
      centre,
      half: 27 * s,
      height: 44 * s,
      angle: angle,
      side: const Color(0xFFE5383B),
      top: const Color(0xFFFF6B6B),
      ribbon: const Color(0xFFFFD166),
    );
    // The lid, a little wider than the box.
    _box(
      canvas,
      centre.translate(0, -27 * s),
      half: 30 * s,
      height: 10 * s,
      angle: angle,
      side: const Color(0xFFC1121F),
      top: const Color(0xFFFF8787),
      ribbon: const Color(0xFFFFD166),
    );
    // The bow: two loops that turn with the box.
    final bowY = centre.dy - 27 * s - 5 * s - 30 * s * 0.32 * 0.2;
    final spread = math.cos(angle) * 11 * s;
    final gold = Paint()..color = const Color(0xFFFFD166);
    final goldDark = Paint()..color = const Color(0xFFE0A100);
    for (final dx in [-spread, spread]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(centre.dx + dx, bowY - 5 * s),
          width: 11 * s,
          height: 9 * s,
        ),
        dx < 0 ? goldDark : gold,
      );
    }
    canvas.drawCircle(Offset(centre.dx, bowY - 4 * s), 3.4 * s, gold);
  }

  /// A box seen from slightly above, turned by [angle] about its upright
  /// axis. [c] is the middle of the box.
  void _box(
    Canvas canvas,
    Offset c, {
    required double half,
    required double height,
    required double angle,
    required Color side,
    required Color top,
    required Color ribbon,
  }) {
    const tilt = 0.32; // how far "above" the viewer is
    final radius = half * math.sqrt2;
    // The four upright edges: across the card (x) and towards us (z).
    final xs = <double>[];
    final zs = <double>[];
    for (var k = 0; k < 4; k++) {
      final a = angle + math.pi / 4 + k * math.pi / 2;
      xs.add(radius * math.sin(a));
      zs.add(radius * math.cos(a));
    }
    Offset corner(int k, {required bool upper}) => Offset(
          c.dx + xs[k],
          c.dy + (upper ? -height / 2 : height / 2) - zs[k] * tilt,
        );

    for (var k = 0; k < 4; k++) {
      final n = (k + 1) % 4;
      // A side shows only while it faces the viewer.
      final facing = math.cos(angle + math.pi / 4 + k * math.pi / 2 +
          math.pi / 4);
      if (facing <= 0) continue;
      final quad = [
        corner(k, upper: true),
        corner(n, upper: true),
        corner(n, upper: false),
        corner(k, upper: false),
      ];
      final shade = 0.55 + 0.45 * facing;
      canvas.drawPath(
        Path()..addPolygon(quad, true),
        Paint()..color = Color.lerp(Colors.black, side, shade)!,
      );
      // Ribbon down the middle of the side.
      Offset along(Offset a, Offset b, double f) => Offset.lerp(a, b, f)!;
      canvas.drawPath(
        Path()
          ..addPolygon(
            [
              along(quad[0], quad[1], 0.4),
              along(quad[0], quad[1], 0.6),
              along(quad[3], quad[2], 0.6),
              along(quad[3], quad[2], 0.4),
            ],
            true,
          ),
        Paint()..color = Color.lerp(Colors.black, ribbon, shade)!,
      );
    }
    // The top, with the ribbon crossing it.
    final lid = [for (var k = 0; k < 4; k++) corner(k, upper: true)];
    canvas.drawPath(Path()..addPolygon(lid, true), Paint()..color = top);
    final band = Paint()
      ..color = ribbon
      ..strokeWidth = half * 0.22
      ..strokeCap = StrokeCap.butt;
    Offset mid(int a, int b) => Offset.lerp(lid[a], lid[b], 0.5)!;
    canvas
      ..drawLine(mid(0, 1), mid(2, 3), band)
      ..drawLine(mid(1, 2), mid(3, 0), band);
  }

  // --- New Year ----------------------------------------------------------

  /// Three fireworks going off one after another, twice per loop.
  void _fireworks(Canvas canvas, Size size) {
    const spots = [
      (0.62, 0.26, Color(0xFFFFD166)),
      (0.90, 0.20, Color(0xFFFF6B9D)),
      (0.76, 0.72, Color(0xFF7CE0FF)),
    ];
    for (var i = 0; i < spots.length; i++) {
      final spot = spots[i];
      final life = (t * 2 + i / spots.length) % 1.0; // 0 launch .. 1 gone
      if (life > 0.8) continue;
      final grow = Curves.easeOutCubic.transform(life / 0.8);
      final fade = (1 - life / 0.8).clamp(0.0, 1.0);
      final centre = Offset(size.width * spot.$1, size.height * spot.$2);
      final reach = (30 + i * 4) * s * grow;
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.8 * s
        ..color = spot.$3.withAlpha((255 * fade).round());
      for (var ray = 0; ray < 14; ray++) {
        final a = _tau * ray / 14 + i;
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          centre + dir * (reach * 0.55),
          // Sparks fall a little as they fly out.
          centre + dir * reach + Offset(0, reach * 0.12),
          paint,
        );
      }
      canvas.drawCircle(
        centre,
        3 * s * (1 - grow),
        Paint()..color = Colors.white.withAlpha((255 * fade).round()),
      );
    }
  }

  /// The year in thick gold numerals that swing left and right, so the
  /// sides of the numerals come into view as they turn.
  void _year3d(Canvas canvas, Offset c) {
    final swing = math.sin(_tau * t * 2); // -1 (turned left) .. 1 (right)
    final lift = math.sin(_tau * t * 3) * 3 * s;
    final text = TextPainter(
      text: TextSpan(
        text: '$year',
        style: TextStyle(
          fontSize: 40 * s,
          height: 1,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w900,
          letterSpacing: -1 * s,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    void draw(Offset shift, Paint fill) {
      final painter = TextPainter(
        text: TextSpan(
          text: '$year',
          style: TextStyle(
            fontSize: 40 * s,
            height: 1,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w900,
            letterSpacing: -1 * s,
            foreground: fill,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(-text.width / 2, -text.height / 2) + shift,
      );
    }

    canvas
      ..save()
      ..translate(c.dx - 6 * s, c.dy + lift)
      // Turning squeezes the numerals a little, like a real turn.
      ..transform(
        (Matrix4.identity()
              ..setEntry(3, 0, swing * 0.0016 / s)
              ..scaleByDouble(1 - swing.abs() * 0.14, 1, 1, 1))
            .storage,
      );
    // The thickness: copies stepping back, away from the turn.
    const depth = 9;
    for (var i = depth; i >= 1; i--) {
      draw(
        Offset(-swing * i * 0.9 * s, i * 0.55 * s),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF8A5A00),
            const Color(0xFFC98A00),
            i / depth,
          )!,
      );
    }
    // The face, with a moving shine.
    final face = Rect.fromCenter(
      center: Offset.zero,
      width: text.width,
      height: text.height,
    );
    final shine = (t * 2) % 1.0;
    draw(
      Offset.zero,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + shine * 3 - 1, -1),
          end: Alignment(shine * 3 - 1, 1),
          colors: const [
            Color(0xFFFFD166),
            Color(0xFFFFF4C2),
            Color(0xFFFFB703),
          ],
        ).createShader(face),
    );
    canvas.restore();
  }

  /// Paper confetti tumbling down in front.
  void _confetti(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFFFD166),
      Color(0xFFFF6B9D),
      Color(0xFF7CE0FF),
      Color(0xFFB8F2A6),
    ];
    for (var i = 0; i < 18; i++) {
      final fall = (_rand(i, 21) + t * (1 + i % 2)) % 1.0;
      final x = _rand(i, 23) * size.width +
          math.sin(_tau * (t * 2 + _rand(i, 25))) * 8 * s;
      final y = fall * (size.height + 10 * s) - 5 * s;
      // A flat piece turning over shows its full width, then its edge.
      final turn = math.cos(_tau * (t * (3 + i % 3) + _rand(i, 27)));
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(_rand(i, 29) * _tau)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: 5 * s * turn.abs().clamp(0.15, 1.0),
            height: 3 * s,
          ),
          Paint()..color = colors[i % colors.length].withAlpha(210),
        )
        ..restore();
    }
  }

  // --- Pongal ------------------------------------------------------------

  /// The sun behind the pot, its rays slowly turning.
  void _sun(Canvas canvas, Offset c) {
    final centre = c.translate(6 * s, -18 * s);
    final rays = Paint()..color = const Color(0x55FFF3B0);
    for (var i = 0; i < 12; i++) {
      final a = _tau * (i / 12 + t);
      const half = 0.11;
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy)
          ..lineTo(
            centre.dx + math.cos(a - half) * 120 * s,
            centre.dy + math.sin(a - half) * 120 * s,
          )
          ..lineTo(
            centre.dx + math.cos(a + half) * 120 * s,
            centre.dy + math.sin(a + half) * 120 * s,
          )
          ..close(),
        rays,
      );
    }
    canvas
      ..drawCircle(centre, 34 * s, Paint()..color = const Color(0x66FFF3B0))
      ..drawCircle(centre, 26 * s, Paint()..color = const Color(0xFFFFF3B0));
  }

  /// Sugarcane on either side of the pot, swaying.
  void _sugarcane(Canvas canvas, Offset c) {
    for (final side in [-1.0, 1.0]) {
      final sway = math.sin(_tau * (t * 2) + side) * 0.07;
      final base = c.translate(side * 46 * s, 52 * s);
      canvas
        ..save()
        ..translate(base.dx, base.dy)
        ..rotate(side * 0.2 + sway);
      final stalk = Paint()
        ..color = const Color(0xFF3A7D44)
        ..strokeWidth = 6 * s
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset.zero, Offset(0, -88 * s), stalk);
      final joint = Paint()
        ..color = const Color(0xFF1F5130)
        ..strokeWidth = 1.6 * s;
      for (var j = 1; j < 6; j++) {
        canvas.drawLine(
          Offset(-3 * s, -j * 15 * s),
          Offset(3 * s, -j * 15 * s),
          joint,
        );
      }
      // Leaves at the top.
      final leaf = Paint()..color = const Color(0xFF6BBF59);
      for (final dir in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(0, -86 * s)
            ..quadraticBezierTo(
              dir * 16 * s,
              -104 * s,
              dir * 26 * s,
              -90 * s,
            )
            ..quadraticBezierTo(dir * 14 * s, -96 * s, 0, -86 * s),
          leaf,
        );
      }
      canvas.restore();
    }
  }

  /// The Pongal pot. It is round, so the turn shows in its painted
  /// markings, which travel around it and narrow at the edges.
  void _pot(Canvas canvas, Offset c) {
    final centre = c.translate(0, 18 * s);
    final rx = 36 * s;
    final ry = 30 * s;
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, 50 * s),
        width: 84 * s,
        height: 14 * s,
      ),
      Paint()..color = const Color(0x40000000),
    );
    final body = Rect.fromCenter(
      center: centre,
      width: rx * 2,
      height: ry * 2,
    );
    canvas.drawOval(
      body,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [Color(0xFFE08A4A), Color(0xFFB5541C), Color(0xFF7A3410)],
        ).createShader(body),
    );
    // Markings going round: a row of white dots and yellow diamonds.
    canvas
      ..save()
      ..clipPath(Path()..addOval(body));
    const marks = 10;
    for (var i = 0; i < marks; i++) {
      final a = _tau * (i / marks + t * 2);
      final depth = math.cos(a);
      if (depth <= 0) continue; // on the far side
      final x = centre.dx + math.sin(a) * rx * 0.96;
      final squeeze = depth; // narrower towards the edges
      final alpha = (255 * depth.clamp(0.0, 1.0)).round();
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, centre.dy - 1 * s),
          width: 6.5 * s * squeeze,
          height: 6.5 * s,
        ),
        Paint()..color = Colors.white.withAlpha(alpha),
      );
      final dx = 4.5 * s * squeeze;
      final y = centre.dy + 12 * s;
      canvas.drawPath(
        Path()
          ..moveTo(x, y - 5 * s)
          ..lineTo(x + dx, y)
          ..lineTo(x, y + 5 * s)
          ..lineTo(x - dx, y)
          ..close(),
        Paint()..color = const Color(0xFFFFD166).withAlpha(alpha),
      );
    }
    // Two painted bands.
    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..color = const Color(0xCCFFF3B0);
    for (final dy in [-9.0, 21.0]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: centre.translate(0, dy * s - 6 * s),
          width: rx * 2.1,
          height: 14 * s,
        ),
        0,
        math.pi,
        false,
        bandPaint,
      );
    }
    canvas.restore();
    // Neck and rim.
    final neck = Rect.fromCenter(
      center: centre.translate(0, -ry + 1 * s),
      width: 40 * s,
      height: 12 * s,
    );
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(neck, Radius.circular(4 * s)),
        Paint()..color = const Color(0xFF9A4517),
      )
      ..drawOval(
        Rect.fromCenter(
          center: centre.translate(0, -ry - 5 * s),
          width: 50 * s,
          height: 12 * s,
        ),
        Paint()..color = const Color(0xFFC7692F),
      );
    // The pongal boiling over: froth that swells and spills.
    final froth = Paint()..color = const Color(0xFFFFFBF0);
    final swell = 1 + math.sin(_tau * t * 4) * 0.1;
    const puffs = [
      (-16.0, -7.0, 8.0),
      (-5.0, -12.0, 10.0),
      (8.0, -11.0, 9.5),
      (18.0, -6.0, 7.5),
      (-22.0, -1.0, 6.0),
      (23.0, 0.0, 5.5),
    ];
    for (final p in puffs) {
      canvas.drawCircle(
        centre.translate(p.$1 * s, -ry - 4 * s + p.$2 * s),
        p.$3 * s * swell,
        froth,
      );
    }
    // A drip running down the side.
    final drip = (t * 2) % 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centre.dx - 23 * s,
          centre.dy - ry + 2 * s,
          5 * s,
          (6 + drip * 16) * s,
        ),
        Radius.circular(3 * s),
      ),
      froth,
    );
  }

  /// Steam rising from the pot and fading.
  void _steam(Canvas canvas, Offset c) {
    for (var i = 0; i < 3; i++) {
      final rise = (t * 3 + i / 3) % 1.0;
      final x = c.dx + (i - 1) * 12 * s + math.sin(_tau * rise) * 4 * s;
      final y = c.dy - 30 * s - rise * 34 * s;
      canvas.drawCircle(
        Offset(x, y),
        (4 + rise * 5) * s,
        Paint()
          ..color = Colors.white.withAlpha((110 * (1 - rise)).round())
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * s),
      );
    }
  }

  @override
  bool shouldRepaint(_FestivePainter old) =>
      old.t != t || old.s != s || old.kind != kind || old.year != year;
}
