import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

typedef PickedImage = ({String name, String mimeType, Uint8List bytes});

/// Opens the browser's file chooser for one image. Completes with null
/// when the chooser is closed without picking a file.
Future<PickedImage?> pickImageFile() {
  final completer = Completer<PickedImage?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/png,image/jpeg,image/webp';

  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS,
  );
  input.addEventListener(
    'change',
    ((web.Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      file.arrayBuffer().toDart.then(
        (buffer) {
          if (completer.isCompleted) return;
          completer.complete((
            name: file.name,
            mimeType: file.type,
            bytes: buffer.toDart.asUint8List(),
          ));
        },
        onError: (Object e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
      );
    }).toJS,
  );
  input.click();
  return completer.future;
}
