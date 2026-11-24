import 'dart:typed_data';

/// The largest logo the server takes: 500 KB (T6.1).
const maxLogoBytes = 500 * 1024;

/// Why [bytes] cannot be a club logo, or null if it is a PNG or JPG of at
/// most 500 KB (T6.1). The texts are the server's.
///
/// The app checks before sending, so a too large photo is refused at once;
/// the server checks again.
String? logoProblem(Uint8List bytes) {
  bool startsWith(List<int> start) =>
      bytes.length >= start.length &&
      [for (var i = 0; i < start.length; i++) bytes[i]].join() == start.join();
  final isPng = startsWith(const [0x89, 0x50, 0x4E, 0x47]);
  final isJpg = startsWith(const [0xFF, 0xD8, 0xFF]);
  if (!isPng && !isJpg) return 'Bitte ein PNG- oder JPG-Bild hochladen.';
  if (bytes.length > maxLogoBytes) {
    return 'Das Logo darf höchstens 500 KB groß sein.';
  }
  return null;
}
