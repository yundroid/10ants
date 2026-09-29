import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/data_store.dart';
import '../services/reports.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'properties_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final txns = store.transactions.where((t) => t.date.year == _year).toList();
    final totals = Totals.of(txns);
    final byProperty =
        Reports.byProperty(store.properties, store.tenants, store.transactions, year: _year);
    final incomeCats = Reports.byCategory(txns, TxType.income);
    final expenseCats = Reports.byCategory(txns, TxType.expense);
    final margin = totals.income == 0 ? null : totals.net / totals.income * 100;

    return Scaffold(
      appBar: AppBar(title: const Text('Hasat raporu'), actions: const [ProfileButton()]),
      body: PageBody(children: [
        Row(children: [
          IconButton(
              onPressed: () => setState(() => _year--), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text('$_year',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          IconButton(
              onPressed: () => setState(() => _year++), icon: const Icon(Icons.chevron_right)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: StatCard(
                  label: 'Gelir',
                  value: money(totals.income),
                  icon: Icons.trending_up,
                  color: AntColors.income(context))),
          const SizedBox(width: 8),
          Expanded(
              child: StatCard(
                  label: 'Gider',
                  value: money(totals.expense),
                  icon: Icons.trending_down,
                  color: AntColors.expense(context))),
        ]),
        const SizedBox(height: 8),
        StatCard(
          label: 'Net kazanç',
          value: money(totals.net),
          icon: Icons.account_balance_wallet_outlined,
          caption: margin == null ? null : 'Kâr marjı %${margin.toStringAsFixed(1).replaceAll('.', ',')}',
        ),
        const SectionTitle('Aylık gelir & gider'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 18, 16, 8),
            child: IncomeExpenseChart(months: Reports.monthsOfYear(store.transactions, _year)),
          ),
        ),
        const SectionTitle('Mülk bazında kazanç'),
        if (byProperty.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Mülk yok.')))
        else
          Card(
            child: Column(children: [
              for (final r in byProperty) _PropertyRow(report: r, best: byProperty.first),
            ]),
          ),
        if (incomeCats.isNotEmpty) ...[
          const SectionTitle('Gelir kalemleri'),
          _CategoryCard(entries: incomeCats, total: totals.income, color: AntColors.income(context)),
        ],
        if (expenseCats.isNotEmpty) ...[
          const SectionTitle('Gider kalemleri'),
          _CategoryCard(
              entries: expenseCats, total: totals.expense, color: AntColors.expense(context)),
        ],
      ]),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.report, required this.best});
  final PropertyReport report;
  final PropertyReport best;

  @override
  Widget build(BuildContext context) {
    final p = report.property;
    final t = report.totals;
    final isBest = p != null && identical(report, best) && t.net > 0;
    return ListTile(
      leading: Icon(p == null ? Icons.folder_open : propertyIcon(p.type)),
      title: Row(children: [
        Flexible(
          child: Text(p?.name ?? 'Genel (mülksüz)',
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
        if (isBest) ...[
          const SizedBox(width: 6),
          const Tooltip(
            message: 'En kârlı mülk',
            child: Icon(Icons.emoji_events, size: 18, color: AntColors.amber),
          ),
        ],
      ]),
      subtitle: Text('Gelir ${money(t.income)} · Gider ${money(t.expense)}'),
      trailing: Text(money(t.net),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: t.net >= 0 ? AntColors.income(context) : AntColors.expense(context),
          )),
      onTap: p == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: p.id!))),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.entries, required this.total, required this.color});
  final List<MapEntry<String, double>> entries;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(e.key)),
                    Text(money(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : e.value / total,
                      minHeight: 6,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.12),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      );
}
