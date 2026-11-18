// Saves bytes as a file download. Implemented for web; elsewhere (unit
// tests, desktop) it reports false so the caller can say so.
export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
