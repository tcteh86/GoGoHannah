import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'csv_picker.dart';

Future<CsvFile?> pickCsvFileImpl() async {
  final input = html.FileUploadInputElement()..accept = '.csv';
  input.click();
  await input.onChange.first;
  final file = input.files?.first;
  if (file == null) {
    return null;
  }
  final reader = html.FileReader();
  final completer = Completer<Uint8List>();
  reader.readAsArrayBuffer(file);
  reader.onLoad.listen((_) {
    final buffer = reader.result as ByteBuffer;
    completer.complete(Uint8List.view(buffer));
  });
  reader.onError.listen((_) {
    completer.completeError(StateError('Failed to read CSV file.'));
  });
  final bytes = await completer.future;
  return CsvFile(name: file.name, bytes: bytes);
}
