import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// The longest side, in pixels, of a photo as it is stored. Enough for a
/// phone's full width at high density; anything larger only costs the
/// customer mobile data.
const photoMaxSide = 1000;

typedef ShrunkPhoto = ({Uint8List bytes, String mimeType, bool changed});

/// Makes a photo small enough to send to customers' phones before it is
/// uploaded: no side longer than [photoMaxSide], saved as a JPEG (or as a
/// PNG when the picture has see-through parts, which a JPEG cannot keep).
///
/// A camera photo of several megabytes comes out at roughly 100 to 200 KB.
/// A photo that is already small, or that cannot be read, is returned as
/// it was ([ShrunkPhoto.changed] false).
Future<ShrunkPhoto> shrinkPhoto(Uint8List bytes, String mimeType) async {
  final ShrunkPhoto original = (
    bytes: bytes,
    mimeType: mimeType,
    changed: false,
  );
  try {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longest = math.max(descriptor.width, descriptor.height);
    final scale = longest > photoMaxSide ? photoMaxSide / longest : 1.0;
    final width = math.max(1, (descriptor.width * scale).round());
    final height = math.max(1, (descriptor.height * scale).round());

    // The browser resizes while it decodes, which is quick even for a
    // large photo.
    final codec = await descriptor.instantiateCodec(
      targetWidth: width,
      targetHeight: height,
    );
    final image = (await codec.getNextFrame()).image;
    final pixels = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    if (pixels == null) return original;

    final rgba = pixels.buffer.asUint8List(
      pixels.offsetInBytes,
      pixels.lengthInBytes,
    );
    var seeThrough = false;
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 255) {
        seeThrough = true;
        break;
      }
    }
    final picture = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final encoded = seeThrough
        ? img.encodePng(picture)
        : img.encodeJpg(picture, quality: 82);
    // Already small and no smaller after saving again: keep the original.
    if (scale == 1.0 && encoded.length >= bytes.length) return original;
    return (
      bytes: Uint8List.fromList(encoded),
      mimeType: seeThrough ? 'image/png' : 'image/jpeg',
      changed: true,
    );
  } catch (_) {
    return original;
  }
}
