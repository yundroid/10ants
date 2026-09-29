import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ten_ants/models/models.dart';
import 'package:ten_ants/services/reports.dart';
import 'package:ten_ants/utils/format.dart';

Txn tx(TxType type, double amount, DateTime date, {int? propertyId, String category = 'X'}) =>
    Txn(userId: 1, propertyId: propertyId, type: type, category: category, amount: amount, date: date);

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  final txns = [
    tx(TxType.income, 10000, DateTime(2026, 1, 5), propertyId: 1, category: 'Kira'),
    tx(TxType.income, 8000, DateTime(2026, 2, 5), propertyId: 2, category: 'Kira'),
    tx(TxType.expense, 1500, DateTime(2026, 2, 10), propertyId: 1, category: 'Aidat'),
    tx(TxType.expense, 700, DateTime(2026, 2, 11), category: 'Fatura'),
    tx(TxType.income, 9000, DateTime(2025, 12, 5), propertyId: 1, category: 'Kira'),
  ];
  const props = [
    Property(id: 1, userId: 1, name: 'A'),
    Property(id: 2, userId: 1, name: 'B'),
  ];

  test('yıl ve ay toplamları', () {
    final y = Reports.forYear(txns, 2026);
    expect(y.income, 18000);
    expect(y.expense, 2200);
    expect(y.net, 15800);
    expect(Reports.forMonth(txns, DateTime(2026, 2)).net, 8000 - 2200);
  });

  test('son N ay yıl sınırını doğru geçer', () {
    final m = Reports.lastMonths(txns, DateTime(2026, 2, 15), 3);
    expect(m.map((e) => e.month), [DateTime(2025, 12), DateTime(2026, 1), DateTime(2026, 2)]);
    expect(m.first.totals.income, 9000);
  });

  test('mülk bazında rapor, genel giderler ayrı satırda', () {
    final r = Reports.byProperty(props, const [], txns, year: 2026);
    expect(r.map((e) => e.property?.name), ['A', 'B', null]);
    expect(r[0].totals.net, 8500);
    expect(r[1].totals.net, 8000);
    expect(r[2].totals.expense, 700);
  });

  test('kategori dağılımı', () {
    final c = Reports.byCategory(txns, TxType.expense);
    expect(c.first.key, 'Aidat');
    expect(c.first.value, 1500);
  });

  test('tutar ayrıştırma (Türkçe biçim)', () {
    expect(parseAmount('12.500,50'), 12500.5);
    expect(parseAmount('12500.5'), 12500.5);
    expect(parseAmount('12.500'), 12500);
    expect(parseAmount('₺ 1.250'), 1250);
    expect(parseAmount('abc'), isNull);
    expect(parseAmount(''), isNull);
  });

  test('tarih ve dönem anahtarları', () {
    expect(dateKey(DateTime(2026, 3, 7)), '2026-03-07');
    expect(periodKey(DateTime(2026, 3, 7)), '2026-03');
    expect(parseDate('2026-03-07'), DateTime(2026, 3, 7));
    expect(fmtPeriod('2026-03'), 'Mart 2026');
    expect(money(1234.5), contains('1.234,50'));
  });
}
