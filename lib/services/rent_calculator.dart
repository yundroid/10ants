import '../models/models.dart';
import '../utils/format.dart';

enum RentStatus {
  paid('Ödendi'),
  partial('Kısmi ödendi'),
  overdue('Gecikmiş'),
  upcoming('Bekleniyor');

  const RentStatus(this.label);
  final String label;
}

/// Bir kiracının tek bir aylık kira dönemi.
class RentPeriod {
  RentPeriod({
    required this.tenant,
    required this.period,
    required this.dueDate,
    required this.expected,
    required this.paid,
    required this.status,
    required this.daysLate,
  });

  final Tenant tenant;
  final String period;
  final DateTime dueDate;
  final double expected;
  final double paid;
  final RentStatus status;
  final int daysLate;

  double get remaining => (expected - paid).clamp(0, double.infinity).toDouble();
}

class RentCalculator {
  static const _epsilon = 0.005;

  /// Kiracının sözleşme başlangıcından bugüne (veya sözleşme bitişine)
  /// kadar olan tüm kira dönemlerini, en yeni dönem önce olacak şekilde döner.
  static List<RentPeriod> ledger(Tenant tenant, Iterable<Txn> txns, DateTime today) {
    today = dateOnly(today);
    final paidByPeriod = <String, double>{};
    for (final t in txns) {
      if (t.isRentPayment && t.tenantId == tenant.id && t.period != null) {
        paidByPeriod.update(t.period!, (v) => v + t.amount, ifAbsent: () => t.amount);
      }
    }

    var last = DateTime(today.year, today.month);
    final end = tenant.leaseEnd ?? (tenant.active ? null : today);
    if (end != null) {
      final endMonth = DateTime(end.year, end.month);
      if (endMonth.isBefore(last)) last = endMonth;
    }

    final result = <RentPeriod>[];
    var cursor = DateTime(tenant.leaseStart.year, tenant.leaseStart.month);
    while (!cursor.isAfter(last)) {
      final key = periodKey(cursor);
      final day = tenant.dueDay.clamp(1, daysInMonth(cursor.year, cursor.month));
      final due = DateTime(cursor.year, cursor.month, day);
      final paid = paidByPeriod[key] ?? 0;
      final expected = tenant.rentAmount;

      RentStatus status;
      var late = 0;
      if (paid + _epsilon >= expected) {
        status = RentStatus.paid;
      } else if (due.isBefore(today)) {
        status = RentStatus.overdue;
        late = today.difference(due).inDays;
      } else if (paid > 0) {
        status = RentStatus.partial;
      } else {
        status = RentStatus.upcoming;
      }

      result.add(RentPeriod(
        tenant: tenant,
        period: key,
        dueDate: due,
        expected: expected,
        paid: paid,
        status: status,
        daysLate: late,
      ));
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return result.reversed.toList();
  }

  /// Tüm kiracıların gecikmiş dönemleri, en çok geciken önce.
  static List<RentPeriod> overdue(
      Iterable<Tenant> tenants, Iterable<Txn> txns, DateTime today) {
    final txList = txns.toList();
    final list = [
      for (final t in tenants)
        ...ledger(t, txList, today).where((p) => p.status == RentStatus.overdue),
    ];
    list.sort((a, b) => b.daysLate.compareTo(a.daysLate));
    return list;
  }

  /// Bu ay içinde vadesi gelecek ve henüz tam ödenmemiş kiralar.
  static List<RentPeriod> upcomingThisMonth(
      Iterable<Tenant> tenants, Iterable<Txn> txns, DateTime today) {
    final key = periodKey(today);
    final txList = txns.toList();
    final list = [
      for (final t in tenants.where((t) => t.active))
        ...ledger(t, txList, today).where((p) =>
            p.period == key &&
            (p.status == RentStatus.upcoming || p.status == RentStatus.partial)),
    ];
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  static double totalDebt(Iterable<RentPeriod> periods) =>
      periods.fold(0.0, (s, p) => s + p.remaining);
}
