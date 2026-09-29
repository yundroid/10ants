import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _currencyShort = NumberFormat.compactCurrency(locale: 'tr_TR', symbol: '₺');
final _date = DateFormat('d MMM yyyy', 'tr_TR');
final _monthYear = DateFormat('MMMM yyyy', 'tr_TR');
final _monthShort = DateFormat('MMM', 'tr_TR');

String money(num v) => _currency.format(v);
String moneyShort(num v) => _currencyShort.format(v);
String fmtDate(DateTime d) => _date.format(d);
String fmtMonthYear(DateTime d) => _monthYear.format(d);
String fmtMonthShort(DateTime d) => _monthShort.format(d);

/// Bir tarihin sadece gün kısmı (saat bilgisi atılmış hali).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _two(int n) => n.toString().padLeft(2, '0');

/// `yyyy-MM-dd`
String dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// `yyyy-MM`
String periodKey(DateTime d) => '${d.year}-${_two(d.month)}';

DateTime parseDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p.length > 2 ? p[2] : 1);
}

DateTime parsePeriod(String s) => parseDate(s);

String fmtPeriod(String period) => fmtMonthYear(parsePeriod(period));

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Kullanıcının girdiği "12.500,50" ya da "12500.5" gibi tutarları çözer.
double? parseAmount(String input) {
  var s = input.trim().replaceAll('₺', '').replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}

String amountInput(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');

/// Türkçe kurallarıyla büyük harf: "kira" → "KİRA", "ılık" → "ILIK".
String trUpper(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
