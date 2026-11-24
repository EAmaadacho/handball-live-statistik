import 'dart:io';

/// The club logos as files in data/logos/, e.g. data/logos/t1.png (T6,
/// ADR-004). The team only keeps the file name.
class LogoStore {
  final Directory _dir;

  LogoStore(String dirPath) : _dir = Directory(dirPath);

  /// Writes the logo of team [teamId] and returns its file name, e.g.
  /// "t1.png". An old logo of the team is removed first, also a JPG.
  String save(String teamId, List<int> bytes, String fileType) {
    _dir.createSync(recursive: true);
    for (final old in ['png', 'jpg']) {
      final file = File('${_dir.path}/$teamId.$old');
      if (file.existsSync()) file.deleteSync();
    }
    final name = '$teamId.$fileType';
    File('${_dir.path}/$name').writeAsBytesSync(bytes, flush: true);
    return name;
  }

  /// The bytes of the logo file [name], or `null` if it is missing.
  List<int>? read(String name) {
    final file = File('${_dir.path}/$name');
    return file.existsSync() ? file.readAsBytesSync() : null;
  }
}
