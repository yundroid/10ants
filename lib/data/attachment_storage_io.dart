import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'attachment_storage.dart';

/// Mobil/masaüstü: ekler uygulama belgeler klasöründe `attachments/` altında.
class _FileAttachmentStorage extends AttachmentStorage {
  _FileAttachmentStorage(this._dir);
  final Directory _dir;

  File _file(String id) => File(p.join(_dir.path, id));

  @override
  Future<void> write(String id, Uint8List bytes) => _file(id).writeAsBytes(bytes, flush: true);

  @override
  Future<Uint8List?> read(String id) async {
    final f = _file(id);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> delete(String id) async {
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }
}

Future<AttachmentStorage> openAttachmentStorage() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'attachments'));
  await dir.create(recursive: true);
  return _FileAttachmentStorage(dir);
}

/// Dosyayı cihazın varsayılan uygulamasıyla (ör. PDF görüntüleyici) açar.
Future<bool> openExternally(Uint8List bytes, String fileName, String mimeType) async {
  final tmp = await getTemporaryDirectory();
  final safe = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
  final file = File(p.join(tmp.path, 'open_${DateTime.now().millisecondsSinceEpoch}_$safe'));
  await file.writeAsBytes(bytes, flush: true);
  final result = await OpenFilex.open(file.path, type: mimeType);
  return result.type == ResultType.done;
}
