import 'dart:typed_data';

import 'csv_picker_stub.dart'
    if (dart.library.html) 'csv_picker_web.dart';

class CsvFile {
  final String name;
  final Uint8List bytes;

  CsvFile({required this.name, required this.bytes});
}

Future<CsvFile?> pickCsvFile() => pickCsvFileImpl();
