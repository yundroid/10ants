import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/contact.dart';
import 'common.dart';

const whatsappGreen = Color(0xFF25D366);

/// Kiracıyı arama ve WhatsApp'tan mesaj gönderme düğmeleri.
/// Telefon yoksa ya da geçersizse bunu belirten bir satır gösterir.
class ContactButtons extends StatelessWidget {
  const ContactButtons({
    super.key,
    required this.tenant,
    required this.message,
    this.onAddPhone,
  });

  final Tenant tenant;

  /// WhatsApp'ta önceden yazılmış gelecek mesaj (gönderilmeden düzenlenebilir).
  final String message;
  final VoidCallback? onAddPhone;

  Future<void> _launch(BuildContext context, Uri? uri, String failMessage) async {
    if (uri == null) {
      showSnack(context, 'Telefon numarası geçersiz: ${tenant.phone}', error: true);
      return;
    }
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) showSnack(context, failMessage, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (tenant.phone.trim().isEmpty || Contact.normalizePhone(tenant.phone) == null) {
      return ListTile(
        leading: Icon(Icons.phone_disabled_outlined, color: cs.outline),
        title: Text(tenant.phone.trim().isEmpty
            ? 'Telefon numarası kayıtlı değil'
            : 'Telefon numarası geçersiz: ${tenant.phone}'),
        subtitle: const Text('Aramak veya WhatsApp\'tan yazmak için numara ekle'),
        trailing: onAddPhone == null
            ? null
            : TextButton(onPressed: onAddPhone, child: const Text('Ekle')),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _launch(context, Contact.telUri(tenant.phone), 'Arama başlatılamadı'),
            icon: const Icon(Icons.call),
            label: const Text('Ara'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: whatsappGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 40),
            ),
            onPressed: () => _launch(
              context,
              Contact.whatsappUri(tenant.phone, message),
              'WhatsApp açılamadı. Uygulamanın yüklü olduğundan emin ol.',
            ),
            icon: const Icon(Icons.chat),
            label: const Text('WhatsApp'),
          ),
        ),
      ]),
    );
  }
}
