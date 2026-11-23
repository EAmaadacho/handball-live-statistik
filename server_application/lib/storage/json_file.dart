import 'dart:convert';
import 'dart:io';

/// Writes [json] to [file] via `<name>.tmp` and renaming, so the file is
/// never left half written, e.g. if the server stops while writing
/// (ADR-004).
void writeJsonFile(File file, Object? json) {
  file.parent.createSync(recursive: true);
  final tmp = File('${file.path}.tmp');
  tmp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  tmp.renameSync(file.path);
}
