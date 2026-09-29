import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ten_ants/models/models.dart';
import 'package:ten_ants/services/contact.dart';
import 'package:ten_ants/services/rent_calculator.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  test('Türkiye numaraları uluslararası biçime çevrilir', () {
    expect(Contact.normalizePhone('0532 123 45 67'), '905321234567');
    expect(Contact.normalizePhone('(0532) 123-45-67'), '905321234567');
    expect(Contact.normalizePhone('532 123 45 67'), '905321234567');
    expect(Contact.normalizePhone('+90 532 123 45 67'), '905321234567');
    expect(Contact.normalizePhone('0090 532 123 45 67'), '905321234567');
    expect(Contact.normalizePhone('+49 151 23456789'), '4915123456789');
    expect(Contact.normalizePhone('123'), isNull);
    expect(Contact.normalizePhone(''), isNull);
  });

  test('arama ve WhatsApp bağlantıları', () {
    expect(Contact.telUri('0532 123 45 67').toString(), 'tel:+905321234567');
    final wa = Contact.whatsappUri('0532 123 45 67', 'Merhaba Ali, kira?')!;
    expect(wa.host, 'wa.me');
    expect(wa.path, '/905321234567');
    expect(wa.queryParameters['text'], 'Merhaba Ali, kira?');
    expect(wa.toString(), contains('Merhaba%20Ali'));
    expect(wa.toString(), isNot(contains('+')));
    expect(Contact.whatsappUri('abc', 'x'), isNull);
  });

  test('hatırlatma mesajı dönemleri ve toplamı içerir', () {
    final t = Tenant(
      id: 1,
      userId: 1,
      propertyId: 1,
      name: 'Mehmet Kaya',
      rentAmount: 18500,
      dueDay: 10,
      leaseStart: DateTime(2026, 8, 1),
    );
    const p = Property(id: 1, userId: 1, name: 'Bahçeli Müstakil');
    final overdue = RentCalculator.overdue([t], [], DateTime(2026, 9, 29));
    final msg = Contact.reminderMessage(t, p, overdue);
    expect(msg, startsWith('Merhaba Mehmet, Bahçeli Müstakil için Ağustos 2026, Eylül 2026 dönemlerine'));
    expect(msg, contains('37.000,00'));

    final one = Contact.reminderMessage(t, p, overdue.take(1).toList());
    expect(one, contains('dönemine ait'));
  });
}
