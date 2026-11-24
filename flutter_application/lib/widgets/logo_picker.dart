import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Lets the user choose a PNG or JPG file and returns its bytes, or null
/// when cancelled (T6). In the browser this opens the file dialog.
Future<Uint8List?> pickLogoFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg'],
  );
  return file?.readAsBytes();
}
