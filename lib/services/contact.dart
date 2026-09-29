import '../models/models.dart';
import '../utils/format.dart';
import 'rent_calculator.dart';

/// Kiracıyla iletişim: arama ve WhatsApp bağlantıları, hatırlatma mesajı.
class Contact {
  /// Telefonu uluslararası biçime (yalnız rakam, ülke koduyla) çevirir.
  /// Türkiye numaraları varsayılır: `0532 123 45 67` → `905321234567`.
  /// Geçersizse `null`.
  static String? normalizePhone(String raw) {
    final hadPlus = raw.trim().startsWith('+');
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return null;
    if (d.startsWith('00')) {
      d = d.substring(2);
    } else if (!hadPlus) {
      if (d.length == 11 && d.startsWith('0')) {
        d = '90${d.substring(1)}';
      } else if (d.length == 10) {
        d = '90$d';
      }
    }
    return d.length >= 10 && d.length <= 15 ? d : null;
  }

  static Uri? telUri(String raw) {
    final n = normalizePhone(raw);
    return n == null ? null : Uri(scheme: 'tel', path: '+$n');
  }

  static Uri? whatsappUri(String raw, String message) {
    final n = normalizePhone(raw);
    if (n == null) return null;
    // Boşluklar "+" yerine %20 olarak kodlanmalı; WhatsApp "+" işaretini
    // bazı sürümlerde olduğu gibi gösteriyor.
    return Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(message)}');
  }

  /// Geciken dönemler için nazik bir hatırlatma mesajı.
  static String reminderMessage(Tenant tenant, Property? property, List<RentPeriod> overdue) {
    final firstName = tenant.name.trim().split(RegExp(r'\s+')).first;
    final sorted = [...overdue]..sort((a, b) => a.period.compareTo(b.period));
    final periods = sorted.map((p) => fmtPeriod(p.period)).join(', ');
    final total = money(RentCalculator.totalDebt(overdue));
    final where = property == null ? '' : '${property.name} için ';
    final count = overdue.length == 1 ? '$periods dönemine' : '$periods dönemlerine';
    return 'Merhaba $firstName, $where$count ait toplam $total kira ödemeniz gecikmiş görünüyor. '
        'Ödemenizi en kısa sürede yapabilirseniz sevinirim. Ödeme yaptıysanız lütfen bu mesajı dikkate almayın. İyi günler.';
  }
}
