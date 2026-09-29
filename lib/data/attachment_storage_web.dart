import 'dart:js_interop';
import 'dart:typed_data';

import 'package:sembast/blob.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:web/web.dart' as web;

import 'attachment_storage.dart';

/// Web: ekler ana veritabanından ayrı bir IndexedDB veritabanında.
/// Veritabanı ilk kullanımda açılır; böylece ekler uygulama açılışında
/// belleğe yüklenmez.
class _WebAttachmentStorage extends AttachmentStorage {
  late final Future<Database> _db = databaseFactoryWeb.openDatabase('10ants-files');
  final _store = StoreRef<String, Blob>('files');

  @override
  Future<void> write(String id, Uint8List bytes) async =>
      _store.record(id).put(await _db, Blob(bytes));

  @override
  Future<Uint8List?> read(String id) async => (await _store.record(id).get(await _db))?.bytes;

  @override
  Future<void> delete(String id) async => _store.record(id).delete(await _db);
}

Future<AttachmentStorage> openAttachmentStorage() async => _WebAttachmentStorage();

/// Dosyayı yeni sekmede açar (PDF'ler tarayıcının görüntüleyicisinde).
Future<bool> openExternally(Uint8List bytes, String fileName, String mimeType) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final win = web.window.open(url, '_blank');
  if (win == null) {
    // Açılır pencere engellendiyse indir.
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    a.click();
  }
  return true;
}
