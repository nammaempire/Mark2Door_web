// Product photo upload from this computer. Implemented for web; elsewhere
// (unit tests) there is no file chooser, so nothing is picked.
export 'image_upload_stub.dart'
    if (dart.library.js_interop) 'image_upload_web.dart';
