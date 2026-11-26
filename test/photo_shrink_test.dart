import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mart2door_admin/core/photo_shrink.dart';

/// A picture with detail in it, so it does not compress to nothing.
img.Image _picture(int width, int height, {bool seeThrough = false}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(
        x,
        y,
        (x * 7 + y * 3) % 256,
        (x * 2 + y * 11) % 256,
        (x * 5 + y * 5) % 256,
        seeThrough && x < width ~/ 2 ? 0 : 255,
      );
    }
  }
  return image;
}

void main() {
  testWidgets('a large camera photo is stored at 1000 pixels as a JPEG', (
    tester,
  ) async {
    final big = Uint8List.fromList(
      img.encodeJpg(_picture(2400, 1800), quality: 95),
    );
    final small = (await tester.runAsync(
      () => shrinkPhoto(big, 'image/jpeg'),
    ))!;
    expect(small.changed, isTrue);
    expect(small.mimeType, 'image/jpeg');
    final decoded = img.decodeJpg(small.bytes)!;
    expect(decoded.width, 1000);
    expect(decoded.height, 750);
    expect(small.bytes.length, lessThan(big.length ~/ 3));
  });

  testWidgets('a tall photo keeps its shape', (tester) async {
    final tall = Uint8List.fromList(img.encodeJpg(_picture(600, 1500)));
    final small = (await tester.runAsync(
      () => shrinkPhoto(tall, 'image/jpeg'),
    ))!;
    final decoded = img.decodeJpg(small.bytes)!;
    expect(decoded.width, 400);
    expect(decoded.height, 1000);
  });

  testWidgets('a picture with see-through parts stays a PNG and keeps them', (
    tester,
  ) async {
    final cutout = Uint8List.fromList(
      img.encodePng(_picture(1600, 1200, seeThrough: true)),
    );
    final small = (await tester.runAsync(
      () => shrinkPhoto(cutout, 'image/png'),
    ))!;
    expect(small.mimeType, 'image/png');
    final decoded = img.decodePng(small.bytes)!;
    expect(decoded.width, 1000);
    expect(decoded.getPixel(10, 10).a, 0);
    expect(decoded.getPixel(990, 10).a, 255);
  });

  testWidgets('a small photo and an unreadable file are left as they are', (
    tester,
  ) async {
    final little = Uint8List.fromList(
      img.encodeJpg(_picture(300, 200), quality: 60),
    );
    final same = (await tester.runAsync(
      () => shrinkPhoto(little, 'image/jpeg'),
    ))!;
    expect(same.bytes.length, lessThanOrEqualTo(little.length));

    final junk = Uint8List.fromList(List.filled(64, 7));
    final kept = (await tester.runAsync(
      () => shrinkPhoto(junk, 'image/jpeg'),
    ))!;
    expect(kept.changed, isFalse);
    expect(kept.bytes, junk);
  });
}
