import '../models/models.dart';

class Totals {
  const Totals(this.income, this.expense);
  final double income;
  final double expense;
  double get net => income - expense;

  static Totals of(Iterable<Txn> txns) {
    var inc = 0.0, exp = 0.0;
    for (final t in txns) {
      if (t.type == TxType.income) {
        inc += t.amount;
      } else {
        exp += t.amount;
      }
    }
    return Totals(inc, exp);
  }
}

class MonthTotals {
  const MonthTotals(this.month, this.totals);
  final DateTime month;
  final Totals totals;
}

class PropertyReport {
  const PropertyReport(this.property, this.totals, this.activeTenants);

  /// `null` ise hiçbir mülke bağlanmamış (genel) hareketler.
  final Property? property;
  final Totals totals;
  final int activeTenants;
}

class Reports {
  static bool _inRange(DateTime d, DateTime from, DateTime toExclusive) =>
      !d.isBefore(from) && d.isBefore(toExclusive);

  static Totals forRange(Iterable<Txn> txns, DateTime from, DateTime toExclusive) =>
      Totals.of(txns.where((t) => _inRange(t.date, from, toExclusive)));

  static Totals forMonth(Iterable<Txn> txns, DateTime month) => forRange(
      txns, DateTime(month.year, month.month), DateTime(month.year, month.month + 1));

  static Totals forYear(Iterable<Txn> txns, int year) =>
      forRange(txns, DateTime(year), DateTime(year + 1));

  /// Son [count] ayın toplamları (eskiden yeniye).
  static List<MonthTotals> lastMonths(Iterable<Txn> txns, DateTime today, int count) {
    final list = txns.toList();
    return [
      for (var i = count - 1; i >= 0; i--)
        () {
          final m = DateTime(today.year, today.month - i);
          return MonthTotals(m, forMonth(list, m));
        }(),
    ];
  }

  static List<MonthTotals> monthsOfYear(Iterable<Txn> txns, int year) {
    final list = txns.toList();
    return [
      for (var m = 1; m <= 12; m++)
        MonthTotals(DateTime(year, m), forMonth(list, DateTime(year, m))),
    ];
  }

  /// Mülk bazında gelir/gider/net. [year] verilmezse tüm zamanlar.
  static List<PropertyReport> byProperty(
    Iterable<Property> properties,
    Iterable<Tenant> tenants,
    Iterable<Txn> txns, {
    int? year,
  }) {
    final filtered =
        txns.where((t) => year == null || t.date.year == year).toList();
    final reports = [
      for (final p in properties)
        PropertyReport(
          p,
          Totals.of(filtered.where((t) => t.propertyId == p.id)),
          tenants.where((t) => t.propertyId == p.id && t.active).length,
        ),
    ];
    reports.sort((a, b) => b.totals.net.compareTo(a.totals.net));
    final general = filtered.where((t) => t.propertyId == null);
    if (general.isNotEmpty) {
      reports.add(PropertyReport(null, Totals.of(general), 0));
    }
    return reports;
  }

  /// Kategori bazında toplamlar (büyükten küçüğe).
  static List<MapEntry<String, double>> byCategory(Iterable<Txn> txns, TxType type) {
    final map = <String, double>{};
    for (final t in txns.where((t) => t.type == type)) {
      map.update(t.category, (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }
}
