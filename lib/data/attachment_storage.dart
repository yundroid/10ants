import 'dart:typed_data';

export 'attachment_storage_io.dart' if (dart.library.js_interop) 'attachment_storage_web.dart'
    show openAttachmentStorage, openExternally;

/// Ek dosyaların (fotoğraf/PDF) baytlarını saklar. Kayıtlar veritabanında
/// sadece [Attachment] üst bilgisini tutar; böylece ana veritabanı küçük kalır.
abstract class AttachmentStorage {
  Future<void> write(String id, Uint8List bytes);
  Future<Uint8List?> read(String id);
  Future<void> delete(String id);

  Future<void> deleteAll(Iterable<String> ids) async {
    for (final id in ids) {
      await delete(id);
    }
  }
}

/// Testler için bellek içi depolama.
class MemoryAttachmentStorage extends AttachmentStorage {
  final files = <String, Uint8List>{};

  @override
  Future<void> write(String id, Uint8List bytes) async => files[id] = bytes;
  @override
  Future<Uint8List?> read(String id) async => files[id];
  @override
  Future<void> delete(String id) async => files.remove(id);
}
