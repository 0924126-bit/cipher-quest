/// Web mp3 file picker using a hidden <input type="file"> element.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class PickedFile {
  final String name;
  final List<int> bytes;
  const PickedFile({required this.name, required this.bytes});
}

Future<PickedFile?> pickMp3File() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.mp3,audio/mpeg';

  final completer = Completer<PickedFile?>();

  void finish(PickedFile? result) {
    if (!completer.isCompleted) completer.complete(result);
  }

  input.onchange = ((web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    reader.onload = ((web.Event _) {
      final buf = reader.result;
      if (buf.isA<JSArrayBuffer>()) {
        final data = (buf as JSArrayBuffer).toDart.asUint8List();
        finish(PickedFile(name: file.name, bytes: data));
      } else {
        finish(null);
      }
    }).toJS;
    reader.onerror = ((web.Event _) => finish(null)).toJS;
    reader.readAsArrayBuffer(file);
  }).toJS;

  input.click();
  return completer.future;
}
