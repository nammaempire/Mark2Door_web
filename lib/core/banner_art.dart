import 'package:flutter/material.dart';

/// Banner designs the admin can pick. Keys are stored in
/// `banners/{id}.layout`; an unknown key is drawn as `classic`.
const bannerLayouts = <String>[
  'classic',
  'emojiLeft',
  'centered',
  'spotlight',
  'offerTag',
  'watermark',
];

/// Draws a promo banner in one of the [bannerLayouts].
///
/// Every measurement is relative to the card height, so the small preview
/// in the admin and the full-size card in the app are the same picture.
/// Needs a bounded height from its parent.
///
/// This file is kept identical in the admin web and the customer app.
class BannerArt extends StatelessWidget {
  const BannerArt({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.colors,
    this.layout = 'classic',
  });

  /// Card height the measurements below were designed at.
  static const referenceHeight = 158.0;

  final String title;
  final String subtitle;
  final String emoji;

  /// Gradient, top-left to bottom-right.
  final List<Color> colors;
  final String layout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = constraints.maxHeight / referenceHeight;
        return ClipRRect(
          borderRadius: BorderRadius.circular(24 * s),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: switch (layout) {
                'emojiLeft' => _emojiLeft(s),
                'centered' => _centered(s),
                'spotlight' => _spotlight(s),
                'offerTag' => _offerTag(s),
                'watermark' => _watermark(s),
                _ => _classic(s),
              },
            ),
          ),
        );
      },
    );
  }

  // --- Designs -----------------------------------------------------------

  /// Text on the left, picture on the right.
  List<Widget> _classic(double s) => [
        _bubble(s, 150, right: -36, top: -36),
        _bubble(s, 100, right: 60, bottom: -50),
        Positioned(
          right: 14 * s,
          top: 0,
          bottom: 0,
          child: Center(child: _emoji(76 * s)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18 * s, 16 * s, 110 * s, 14 * s),
          child: _textColumn(s),
        ),
      ];

  /// Picture in a soft circle on the left, text on the right.
  List<Widget> _emojiLeft(double s) => [
        _bubble(s, 150, left: -40, bottom: -50),
        _bubble(s, 110, right: -30, top: -40),
        Padding(
          padding: EdgeInsets.all(16 * s),
          child: Row(
            children: [
              Container(
                width: 96 * s,
                height: 96 * s,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0x33FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: _emoji(54 * s),
              ),
              SizedBox(width: 14 * s),
              Expanded(child: _textColumn(s)),
            ],
          ),
        ),
      ];

  /// Picture on top, text centred underneath.
  List<Widget> _centered(double s) => [
        _bubble(s, 140, left: -50, top: -50),
        _bubble(s, 150, right: -50, bottom: -60),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 12 * s),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _emoji(40 * s),
              SizedBox(height: 4 * s),
              _title(s, size: 17, align: TextAlign.center),
              SizedBox(height: 3 * s),
              _subtitle(s, align: TextAlign.center),
            ],
          ),
        ),
      ];

  /// Picture on a white disc that runs off the right edge.
  List<Widget> _spotlight(double s) => [
        Positioned(
          right: -40 * s,
          top: -6 * s,
          child: Container(
            width: 170 * s,
            height: 170 * s,
            decoration: const BoxDecoration(
              color: Color(0xF2FFFFFF),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: 22 * s,
          top: 0,
          bottom: 0,
          child: Center(child: _emoji(70 * s)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18 * s, 16 * s, 142 * s, 14 * s),
          child: _textColumn(s),
        ),
      ];

  /// Subtitle as an offer tag, large title, tilted picture in the corner.
  List<Widget> _offerTag(double s) => [
        _bubble(s, 130, right: -30, top: -50),
        Positioned(
          right: -12 * s,
          bottom: -24 * s,
          child: Transform.rotate(angle: -0.2, child: _emoji(104 * s)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18 * s, 16 * s, 104 * s, 16 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (subtitle.isNotEmpty) ...[
                _pill(s, subtitle),
                SizedBox(height: 10 * s),
              ],
              _title(s, size: 22, weight: FontWeight.w900),
            ],
          ),
        ),
      ];

  /// Oversized faded picture behind the text.
  List<Widget> _watermark(double s) => [
        Positioned(
          right: -30 * s,
          top: -22 * s,
          child: Opacity(opacity: 0.22, child: _emoji(170 * s)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18 * s, 16 * s, 70 * s, 14 * s),
          child: _textColumn(s),
        ),
      ];

  // --- Pieces ------------------------------------------------------------

  /// Title, subtitle and the "Shop now" pill.
  Widget _textColumn(double s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(s),
          SizedBox(height: 4 * s),
          _subtitle(s),
          const Spacer(),
          _pill(s, 'Shop now'),
        ],
      );

  Widget _title(
    double s, {
    double size = 19,
    TextAlign align = TextAlign.start,
    FontWeight weight = FontWeight.w800,
  }) =>
      Text(
        title,
        maxLines: 2,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * s,
          height: 1.2,
          fontWeight: weight,
        ),
      );

  Widget _subtitle(double s, {TextAlign align = TextAlign.start}) => Text(
        subtitle,
        maxLines: 1,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: const Color(0xE6FFFFFF), fontSize: 13 * s),
      );

  Widget _pill(double s, String label) => Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 7 * s),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20 * s),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12 * s,
            fontWeight: FontWeight.w800,
            color: colors.last,
          ),
        ),
      );

  Widget _emoji(double size) => Text(
        emoji,
        style: TextStyle(
          fontSize: size,
          height: 1.1,
          fontFamilyFallback: const ['Noto Color Emoji'],
        ),
      );

  /// Translucent decorative circle; offsets are at [referenceHeight].
  Widget _bubble(
    double s,
    double size, {
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) =>
      Positioned(
        left: left == null ? null : left * s,
        top: top == null ? null : top * s,
        right: right == null ? null : right * s,
        bottom: bottom == null ? null : bottom * s,
        child: Container(
          width: size * s,
          height: size * s,
          decoration: const BoxDecoration(
            color: Color(0x24FFFFFF),
            shape: BoxShape.circle,
          ),
        ),
      );
}
