import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Festival banner designs with moving 3D artwork. Keys are stored in
/// `banners/{id}.layout` next to the ordinary designs.
///
/// * `christmas`: a spinning gift box in falling snow.
/// * `newYear`: the coming year in swaying 3D numerals, with fireworks.
/// * `pongal`: a turning Pongal pot boiling over, under a spinning sun.
/// * `christmasTree`: a Christmas tree at night with a string of lights
///   circling it and a turning star.
/// * `newYearBalloons`: the coming year on four floating balloons.
/// * `pongalKites`: kites turning in the wind over the harvest fields.
///
/// This file is kept identical in the admin web and the customer app.
const festiveLayouts = <String>[
  'christmas',
  'christmasTree',
  'newYear',
  'newYearBalloons',
  'pongal',
  'pongalKites',
];

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
        'christmasTree' => const [Color(0xFF14506E), Color(0xFF071E33)],
        'newYearBalloons' => const [Color(0xFFC2185B), Color(0xFF4A148C)],
        'pongalKites' => const [Color(0xFF29B6D8), Color(0xFF0B6E99)],
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
      case 'christmasTree':
        _twinkles(canvas, size, 30);
        _snow(canvas, size, far: true);
        _ground(canvas, size);
        _tree(canvas, hero);
        _snow(canvas, size, far: false);
      case 'newYearBalloons':
        _twinkles(canvas, size, 40);
        _balloons(canvas, hero);
        _confetti(canvas, size);
      case 'pongalKites':
        _sun(canvas, hero.translate(-6 * s, 62 * s));
        _fields(canvas, size);
        _kites(canvas, hero);
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

  // --- Shared ------------------------------------------------------------

  /// Small four-pointed stars that fade in and out across the card.
  void _twinkles(Canvas canvas, Size size, int salt) {
    for (var i = 0; i < 14; i++) {
      final glow = (math.sin(_tau * (t * (2 + i % 3) + _rand(i, salt))) + 1) / 2;
      final centre = Offset(
        _rand(i, salt + 1) * size.width,
        _rand(i, salt + 2) * size.height * 0.8,
      );
      final r = (1.5 + _rand(i, salt + 3) * 2.5) * s * (0.5 + glow * 0.5);
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy - r)
          ..quadraticBezierTo(centre.dx, centre.dy, centre.dx + r, centre.dy)
          ..quadraticBezierTo(centre.dx, centre.dy, centre.dx, centre.dy + r)
          ..quadraticBezierTo(centre.dx, centre.dy, centre.dx - r, centre.dy)
          ..quadraticBezierTo(centre.dx, centre.dy, centre.dx, centre.dy - r)
          ..close(),
        Paint()..color = Colors.white.withAlpha((60 + glow * 170).round()),
      );
    }
  }

  /// A five-pointed star around [centre]; [squash] narrows it sideways,
  /// as a flat star looks when it turns away.
  Path _starPath(Offset centre, double outer, double squash) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : outer * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final point = Offset(
        centre.dx + math.cos(a) * r * squash,
        centre.dy + math.sin(a) * r,
      );
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  // --- Christmas tree ----------------------------------------------------

  /// A tree with a string of lights wound round it. The string turns, so
  /// each light passes behind the tree (drawn first, dim and small) and
  /// then across the front (drawn last, bright and large).
  void _tree(Canvas canvas, Offset c) {
    final base = c.dy + 46 * s; // where the lowest branches end
    final height = 96 * s;
    final top = base - height;

    // One light on the string: [h] is how far up the tree it hangs.
    void light(int i, {required bool front}) {
      const count = 22;
      final h = (i + 0.5) / count;
      final a = _tau * (h * 3.5 + t * 2);
      final depth = math.sin(a); // -1 behind the tree .. 1 in front
      if ((depth > 0) != front) return;
      final radius = (48 - 42 * h) * s;
      final at = Offset(
        c.dx + math.cos(a) * radius,
        base - 6 * s - h * (height - 14 * s) + depth * radius * 0.16,
      );
      const colors = [
        Color(0xFFFFD166),
        Color(0xFFFF5C5C),
        Color(0xFF7CE0FF),
        Color(0xFFFF9FF3),
      ];
      final blink = (math.sin(_tau * (t * 6 + _rand(i, 61))) + 1) / 2;
      final size = (front ? 2.6 + depth * 1.2 : 1.6) * s;
      final color = colors[i % colors.length];
      if (front) {
        canvas.drawCircle(
          at,
          size * 2.2,
          Paint()
            ..color = color.withAlpha((50 + blink * 70).round())
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * s),
        );
      }
      canvas.drawCircle(
        at,
        size,
        Paint()..color = color.withAlpha(front ? 255 : 90),
      );
    }

    // Shadow on the snow, then the lights behind the tree.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, base + 16 * s),
        width: 84 * s,
        height: 12 * s,
      ),
      Paint()..color = const Color(0x33000000),
    );
    for (var i = 0; i < 22; i++) {
      light(i, front: false);
    }

    // Trunk.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - 6 * s, base - 4 * s, 12 * s, 22 * s),
        Radius.circular(2 * s),
      ),
      Paint()..color = const Color(0xFF6D4326),
    );

    // Three tiers, widest at the bottom, each lit from the left.
    for (var tier = 0; tier < 3; tier++) {
      final half = (46 - tier * 11) * s;
      final tierBase = base - tier * 27 * s;
      final tierTop = tier == 2 ? top : tierBase - 44 * s;
      final rect = Rect.fromLTRB(c.dx - half, tierTop, c.dx + half, tierBase);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, tierTop)
          ..lineTo(c.dx + half, tierBase)
          ..quadraticBezierTo(c.dx, tierBase + 7 * s, c.dx - half, tierBase)
          ..close(),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF43C77A), Color(0xFF178A4C), Color(0xFF0A5A30)],
            stops: [0, 0.55, 1],
          ).createShader(rect),
      );
    }

    for (var i = 0; i < 22; i++) {
      light(i, front: true);
    }

    // The star on top turns like a weather vane and glows.
    final glow = (math.sin(_tau * t * 4) + 1) / 2;
    final star = Offset(c.dx, top - 3 * s);
    canvas
      ..drawCircle(
        star,
        (13 + glow * 4) * s,
        Paint()
          ..color = const Color(0xFFFFE08A).withAlpha((70 + glow * 60).round())
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * s),
      )
      ..drawPath(
        _starPath(
          star,
          10 * s,
          math.cos(_tau * t * 2).abs().clamp(0.25, 1.0),
        ),
        Paint()..color = const Color(0xFFFFD54F),
      );
  }

  // --- New Year balloons -------------------------------------------------

  /// Four balloons, one for each numeral of the year, bobbing on their
  /// strings. The light on each slides across as it turns.
  void _balloons(Canvas canvas, Offset c) {
    final digits = '$year'.padLeft(4, '0');
    const colors = [
      Color(0xFFFFD166),
      Color(0xFF7CE0FF),
      Color(0xFFFF8FB1),
      Color(0xFFB8F2A6),
    ];
    const heights = [-6.0, -24.0, -12.0, -30.0];
    final knot = Offset(c.dx, c.dy + 74 * s); // where the strings gather

    for (var i = 0; i < 4; i++) {
      final phase = i * 0.23;
      final bob = math.sin(_tau * (t * 2 + phase)) * 5 * s;
      final sway = math.sin(_tau * (t + phase)) * 4 * s;
      final turn = math.sin(_tau * (t * 2 + phase)); // -1 .. 1
      final centre = Offset(
        c.dx + (i - 1.5) * 29 * s + sway,
        c.dy + heights[i] * s + bob,
      );
      final w = 15.5 * s, h = 18.5 * s;
      final body = Rect.fromCenter(center: centre, width: w * 2, height: h * 2);

      // String, curving down to the knot.
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy + h + 3 * s)
          ..quadraticBezierTo(
            centre.dx - sway * 2,
            (centre.dy + h + knot.dy) / 2,
            knot.dx,
            knot.dy,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9 * s
          ..color = Colors.white.withAlpha(150),
      );

      // Body: a ball of colour with the light sliding across it.
      canvas
        ..drawOval(
          body,
          Paint()
            ..shader = RadialGradient(
              center: Alignment(-0.35 + turn * 0.3, -0.45),
              radius: 1.05,
              colors: [
                Color.lerp(colors[i], Colors.white, 0.75)!,
                colors[i],
                Color.lerp(colors[i], Colors.black, 0.35)!,
              ],
              stops: const [0, 0.45, 1],
            ).createShader(body),
        )
        // The tied end.
        ..drawPath(
          Path()
            ..moveTo(centre.dx, centre.dy + h - 1 * s)
            ..lineTo(centre.dx - 3 * s, centre.dy + h + 4 * s)
            ..lineTo(centre.dx + 3 * s, centre.dy + h + 4 * s)
            ..close(),
          Paint()..color = Color.lerp(colors[i], Colors.black, 0.25)!,
        );

      // The numeral, narrowing a little as the balloon turns.
      final numeral = TextPainter(
        text: TextSpan(
          text: digits[i],
          style: TextStyle(
            fontSize: 21 * s,
            height: 1,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w900,
            color: const Color(0xFF3A0F5C),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas
        ..save()
        ..translate(centre.dx + turn * 2 * s, centre.dy)
        ..scale(0.8 + 0.2 * math.cos(turn * math.pi / 2), 1);
      numeral.paint(canvas, Offset(-numeral.width / 2, -numeral.height / 2));
      canvas.restore();
    }
  }

  // --- Pongal kites ------------------------------------------------------

  /// Harvest fields along the bottom, in two rolling rows.
  void _fields(Canvas canvas, Size size) {
    void row(double rise, double sag, Color color) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.3, size.height)
          ..quadraticBezierTo(
            size.width * 0.7,
            size.height - sag * s,
            size.width,
            size.height - rise * s,
          )
          ..lineTo(size.width, size.height)
          ..close(),
        Paint()..color = color,
      );
    }

    row(30, 46, const Color(0xFF7CB518));
    row(14, 26, const Color(0xFF4F9A1F));
  }

  /// Three kites at different distances. Each leans with the wind and
  /// turns side-on and back, so its two halves swap light and shade, and
  /// its tail ripples behind it.
  void _kites(Canvas canvas, Offset c) {
    const kites = [
      // dx, dy, size, colours of the two halves
      (-34.0, -4.0, 12.0, Color(0xFFFFE066), Color(0xFFF4A300)),
      (30.0, -6.0, 15.0, Color(0xFFFF8FB1), Color(0xFFD81B60)),
      (-4.0, -34.0, 20.0, Color(0xFFFF7043), Color(0xFFC62828)),
    ];
    for (var i = 0; i < kites.length; i++) {
      final (dx, dy, size, light, dark) = kites[i];
      final phase = i * 0.31;
      final centre = Offset(
        c.dx + dx * s + math.sin(_tau * (t + phase)) * 7 * s,
        c.dy + dy * s + math.cos(_tau * (t * 2 + phase)) * 4 * s,
      );
      final lean = math.sin(_tau * (t * 2 + phase)) * 0.3;
      final yaw = math.cos(_tau * (t + phase)); // 1 facing us .. -1 turned
      final w = size * s * (0.35 + 0.65 * yaw.abs());
      final h = size * s * 1.25;

      // The line down to whoever is flying it, off the card.
      canvas.drawLine(
        centre,
        Offset(centre.dx - 70 * s, centre.dy + 150 * s),
        Paint()
          ..strokeWidth = 0.7 * s
          ..color = Colors.white.withAlpha(120),
      );

      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(lean);

      // Tail: a ribbon rippling away from the bottom point.
      final tail = Path()..moveTo(0, h * 1.1);
      for (var k = 1; k <= 8; k++) {
        tail.lineTo(
          math.sin(_tau * (t * 4 + phase) + k * 0.9) * (2 + k * 0.6) * s,
          h * 1.1 + k * size * 0.42 * s,
        );
      }
      canvas.drawPath(
        tail,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = light,
      );

      // The two halves: the one turned towards the sun is the light one.
      final left = Path()
        ..moveTo(0, -h)
        ..lineTo(-w, 0)
        ..lineTo(0, h * 1.1)
        ..close();
      final right = Path()
        ..moveTo(0, -h)
        ..lineTo(w, 0)
        ..lineTo(0, h * 1.1)
        ..close();
      canvas
        ..drawPath(left, Paint()..color = yaw >= 0 ? light : dark)
        ..drawPath(right, Paint()..color = yaw >= 0 ? dark : light)
        // The two sticks.
        ..drawLine(
          Offset(0, -h),
          Offset(0, h * 1.1),
          Paint()
            ..strokeWidth = 0.8 * s
            ..color = const Color(0x66000000),
        )
        ..drawLine(
          Offset(-w, 0),
          Offset(w, 0),
          Paint()
            ..strokeWidth = 0.8 * s
            ..color = const Color(0x66000000),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_FestivePainter old) =>
      old.t != t || old.s != s || old.kind != kind || old.year != year;
}
