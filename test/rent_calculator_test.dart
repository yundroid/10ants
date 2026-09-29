import 'package:flutter_test/flutter_test.dart';
import 'package:ten_ants/models/models.dart';
import 'package:ten_ants/services/rent_calculator.dart';

Tenant tenant({
  int id = 1,
  DateTime? start,
  DateTime? end,
  int dueDay = 5,
  double rent = 10000,
  bool active = true,
}) =>
    Tenant(
      id: id,
      userId: 1,
      propertyId: 1,
      name: 'Ali',
      rentAmount: rent,
      dueDay: dueDay,
      leaseStart: start ?? DateTime(2026, 6, 1),
      leaseEnd: end,
      active: active,
    );

Txn pay(String period, double amount, {int tenantId = 1}) => Txn(
      userId: 1,
      propertyId: 1,
      tenantId: tenantId,
      type: TxType.income,
      category: TxCategories.rent,
      amount: amount,
      date: DateTime(2026, 9, 1),
      period: period,
    );

void main() {
  final today = DateTime(2026, 9, 10);

  test('sözleşme başından bugünkü aya kadar dönem üretir (yeniden eskiye)', () {
    final l = RentCalculator.ledger(tenant(), [], today);
    expect(l.map((p) => p.period), ['2026-09', '2026-08', '2026-07', '2026-06']);
  });

  test('ödenen, kısmi, gecikmiş ve bekleyen durumları', () {
    final t = tenant(dueDay: 15);
    final l = RentCalculator.ledger(
      t,
      [pay('2026-06', 10000), pay('2026-07', 4000), pay('2026-09', 2000)],
      today,
    );
    final byPeriod = {for (final p in l) p.period: p};
    expect(byPeriod['2026-06']!.status, RentStatus.paid);
    expect(byPeriod['2026-07']!.status, RentStatus.overdue);
    expect(byPeriod['2026-07']!.remaining, 6000);
    expect(byPeriod['2026-08']!.status, RentStatus.overdue);
    expect(byPeriod['2026-08']!.daysLate, 26);
    // Eylül vadesi 15'inde; bugün 10'u → kısmi ödenmiş, henüz gecikmedi.
    expect(byPeriod['2026-09']!.status, RentStatus.partial);
  });

  test('vade günü bugünse henüz gecikmiş sayılmaz', () {
    final l = RentCalculator.ledger(tenant(dueDay: 10, start: DateTime(2026, 9, 1)), [], today);
    expect(l.single.status, RentStatus.upcoming);
  });

  test('kısa aylarda vade ayın son gününe çekilir', () {
    final l = RentCalculator.ledger(
        tenant(dueDay: 31, start: DateTime(2026, 2, 1)), [], DateTime(2026, 3, 5));
    final feb = l.firstWhere((p) => p.period == '2026-02');
    expect(feb.dueDate, DateTime(2026, 2, 28));
  });

  test('sözleşme bitişinden sonra dönem üretilmez', () {
    final l = RentCalculator.ledger(tenant(end: DateTime(2026, 7, 20)), [], today);
    expect(l.map((p) => p.period), ['2026-07', '2026-06']);
  });

  test('başka kiracının ödemeleri sayılmaz', () {
    final l = RentCalculator.ledger(tenant(), [pay('2026-06', 10000, tenantId: 2)], today);
    expect(l.last.status, RentStatus.overdue);
  });

  test('overdue en çok geciken önce sıralanır ve toplam borç doğru', () {
    final list = RentCalculator.overdue(
      [tenant(id: 1), tenant(id: 2, start: DateTime(2026, 8, 1), rent: 5000)],
      [pay('2026-06', 10000)],
      today,
    );
    expect(list.first.period, '2026-07');
    // Kiracı 1: Temmuz, Ağustos, Eylül (vade 5'i geçti). Kiracı 2: Ağustos, Eylül.
    expect(list.length, 5);
    expect(RentCalculator.totalDebt(list), 3 * 10000 + 2 * 5000);
  });

  test('bu ay beklenen ödemeler', () {
    final list = RentCalculator.upcomingThisMonth([tenant(dueDay: 20)], [], today);
    expect(list.single.period, '2026-09');
  });
}
