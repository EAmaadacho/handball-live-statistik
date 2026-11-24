import 'rule_violation.dart';

/// The largest logo the server takes: 500 KB (T6.1).
const maxLogoBytes = 500 * 1024;

/// Checks an uploaded club logo and returns its file type, "png" or "jpg"
/// (T6.1).
///
/// The type is read from the first bytes of the file, not from its name:
/// every PNG starts with 89 50 4E 47, every JPG with FF D8 FF.
/// Example: a 300 KB PNG of TV Mettmann gives "png", a PDF is rejected.
String checkLogo(List<int> bytes) {
  if (bytes.length > maxLogoBytes) {
    throw const RuleViolation('Das Logo darf höchstens 500 KB groß sein.');
  }
  if (_startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47])) return 'png';
  if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) return 'jpg';
  throw const RuleViolation('Bitte ein PNG- oder JPG-Bild hochladen.');
}

bool _startsWith(List<int> bytes, List<int> start) =>
    bytes.length >= start.length &&
    [for (var i = 0; i < start.length; i++) bytes[i] == start[i]]
        .every((same) => same);
