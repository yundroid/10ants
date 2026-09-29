import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/attachment_storage.dart';
import '../models/models.dart';
import '../services/data_store.dart';
import '../theme.dart';
import 'common.dart';

const _uuid = Uuid();

String fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB';
}

/// Seçilen bir dosya: üst bilgi + baytlar.
typedef PickedFile = ({Attachment attachment, Uint8List bytes});

/// Gelir/gider formundaki "Belgeler" bölümü: fiş, fatura veya dekont
/// fotoğrafı çekme, dosyadan fotoğraf/PDF seçme, önizleme ve kaldırma.
class AttachmentsField extends StatelessWidget {
  const AttachmentsField({
    super.key,
    required this.attachments,
    required this.pendingBytes,
    required this.onAdd,
    required this.onRemove,
  });

  final List<Attachment> attachments;

  /// Henüz kaydedilmemiş eklerin baytları (önizleme için).
  final Map<String, Uint8List> pendingBytes;
  final ValueChanged<PickedFile> onAdd;
  final ValueChanged<Attachment> onRemove;

  bool get _full => attachments.length >= Attachment.maxPerTxn;

  Future<void> _pickFiles(BuildContext context) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: Attachment.allowedExtensions,
    );
    for (final f in picked) {
      if (!context.mounted) return;
      final bytes = await f.readAsBytes();
      if (!context.mounted) return;
      _add(context, f.name, bytes);
    }
  }

  Future<void> _takePhoto(BuildContext context) async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2200,
      maxHeight: 2200,
      imageQuality: 80,
    );
    if (x == null || !context.mounted) return;
    final bytes = await x.readAsBytes();
    if (!context.mounted) return;
    final name = x.name.contains('.') ? x.name : '${x.name}.jpg';
    _add(context, name, bytes);
  }

  void _add(BuildContext context, String name, Uint8List bytes) {
    final mime = Attachment.mimeFor(name);
    if (mime == null) {
      showSnack(context, '"$name" desteklenmiyor. Fotoğraf (JPG, PNG) veya PDF seçin.', error: true);
      return;
    }
    if (bytes.length > Attachment.maxBytes) {
      showSnack(context, '"$name" çok büyük (en fazla 10 MB).', error: true);
      return;
    }
    if (_full) {
      showSnack(context, 'En fazla ${Attachment.maxPerTxn} belge eklenebilir.', error: true);
      return;
    }
    onAdd((
      attachment: Attachment(id: _uuid.v4(), name: name, mimeType: mime, size: bytes.length),
      bytes: bytes,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Belgeler (fiş, fatura, dekont)',
        contentPadding: EdgeInsets.fromLTRB(12, 16, 12, 12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (attachments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Fotoğraf veya PDF ekleyebilirsin (en fazla ${Attachment.maxPerTxn}, her biri 10 MB).',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in attachments)
              AttachmentThumb(
                attachment: a,
                bytes: pendingBytes[a.id],
                onRemove: () => onRemove(a),
              ),
          ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (!kIsWeb)
            OutlinedButton.icon(
              onPressed: _full ? null : () => _takePhoto(context),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Fotoğraf çek'),
            ),
          OutlinedButton.icon(
            onPressed: _full ? null : () => _pickFiles(context),
            icon: const Icon(Icons.attach_file),
            label: const Text('Dosya seç'),
          ),
        ]),
      ]),
    );
  }
}

/// Ekin küçük önizlemesi. Fotoğraflarda görsel, PDF'lerde simge gösterir;
/// dokununca açar.
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb({super.key, required this.attachment, this.bytes, this.onRemove});
  final Attachment attachment;
  final Uint8List? bytes;
  final VoidCallback? onRemove;

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = attachment;
    Widget preview;
    if (a.isImage) {
      preview = _ImageFromStore(attachment: a, bytes: bytes, fit: BoxFit.cover);
    } else {
      preview = Container(
        color: AntColors.berry.withValues(alpha: 0.1),
        child: const Center(
          child: Icon(Icons.picture_as_pdf, size: 36, color: AntColors.berry),
        ),
      );
    }
    return SizedBox(
      width: _size,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Material(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            child: InkWell(
              onTap: () => openAttachment(context, a, bytes: bytes),
              child: SizedBox.square(dimension: _size, child: preview),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text(a.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall),
        Text(fileSize(a.size),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

class _ImageFromStore extends StatelessWidget {
  const _ImageFromStore({required this.attachment, this.bytes, this.fit});
  final Attachment attachment;
  final Uint8List? bytes;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    Widget img(Uint8List b) => Image.memory(
          b,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
        );
    if (bytes != null) return img(bytes!);
    return FutureBuilder<Uint8List?>(
      future: context.read<DataStore>().readAttachment(attachment),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final b = snap.data;
        return b == null ? const Center(child: Icon(Icons.broken_image_outlined)) : img(b);
      },
    );
  }
}

/// Eki açar: fotoğraflar uygulama içinde yakınlaştırılabilir görüntüleyicide,
/// PDF'ler cihazın PDF uygulamasında (web'de yeni sekmede).
Future<void> openAttachment(BuildContext context, Attachment a, {Uint8List? bytes}) async {
  final data = bytes ?? await context.read<DataStore>().readAttachment(a);
  if (!context.mounted) return;
  if (data == null) {
    showSnack(context, 'Dosya bulunamadı', error: true);
    return;
  }
  if (a.isImage) {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ImageViewer(attachment: a, bytes: data),
    ));
    return;
  }
  final ok = await openExternally(data, a.name, a.mimeType);
  if (!ok && context.mounted) {
    showSnack(context, 'Bu dosyayı açabilecek bir uygulama bulunamadı', error: true);
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.attachment, required this.bytes});
  final Attachment attachment;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(attachment.name, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Başka uygulamada aç',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openExternally(bytes, attachment.name, attachment.mimeType),
            ),
          ],
        ),
        body: InteractiveViewer(
          maxScale: 6,
          child: Center(child: Image.memory(bytes)),
        ),
      );
}
