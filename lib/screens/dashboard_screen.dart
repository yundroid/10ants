import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/data_store.dart';
import '../services/rent_calculator.dart';
import '../services/reports.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/ant_art.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'overdue_screen.dart';
import 'tenants_screen.dart';
import 'transactions_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final name = context.select<AuthService, String>((a) => a.currentUser?.name ?? '');
    final today = store.today;
    final month = Reports.forMonth(store.transactions, today);
    final year = Reports.forYear(store.transactions, today.year);
    final overdue = store.overdue;
    final upcoming = store.upcomingThisMonth;
    final vacant = store.properties.where(store.isVacant).length;
    final firstName = name.split(' ').first;

    Widget grid(List<Widget> cards) => LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 640 ? 4 : 2;
          const gap = 12.0;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final card in cards) SizedBox(width: w, child: card)],
          );
        });

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const AntLogo(size: 28),
          const SizedBox(width: 8),
          Flexible(child: Text('Merhaba $firstName', overflow: TextOverflow.ellipsis)),
        ]),
        actions: const [ProfileButton()],
      ),
      body: RefreshIndicator(
        onRefresh: store.reload,
        child: store.properties.isEmpty && !store.loading
            ? ListView(children: [
                const SizedBox(height: 60),
                EmptyState(
                  title: 'Yuvan henüz boş',
                  message:
                      'İlk mülkünü ekleyerek başla. Sonra kiracılarını ekleyip kira ve giderlerini takip edebilirsin.',
                  actionLabel: 'Mülk ekle',
                  onAction: () => HomeShell.of(context).goTo(HomeShellState.tabProperties),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await store.seedDemoData();
                      if (context.mounted) {
                        showSnack(context, 'Örnek veriler yüklendi. Mülkleri silerek temizleyebilirsin.');
                      }
                    },
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Örnek verilerle dene'),
                  ),
                ),
              ])
            : PageBody(children: [
                Text(fmtMonthYear(today),
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 10),
                grid([
                  StatCard(
                    label: 'Bu ay gelir',
                    value: money(month.income),
                    icon: Icons.trending_up,
                    color: AntColors.income(context),
                  ),
                  StatCard(
                    label: 'Bu ay gider',
                    value: money(month.expense),
                    icon: Icons.trending_down,
                    color: AntColors.expense(context),
                  ),
                  StatCard(
                    label: 'Bu ay net',
                    value: money(month.net),
                    icon: Icons.savings_outlined,
                    caption: '${today.year} net: ${money(year.net)}',
                  ),
                  StatCard(
                    label: 'Geciken kira',
                    value: money(RentCalculator.totalDebt(overdue)),
                    icon: Icons.warning_amber_rounded,
                    color: overdue.isEmpty ? AntColors.income(context) : AntColors.expense(context),
                    caption: overdue.isEmpty ? 'Her şey yolunda' : '${overdue.length} dönem gecikmede',
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const OverdueScreen())),
                  ),
                ]),
                const SizedBox(height: 12),
                grid([
                  StatCard(
                    label: 'Mülk',
                    value: '${store.properties.length}',
                    icon: Icons.apartment,
                    caption: vacant == 0 ? 'Hepsi dolu' : '$vacant boş',
                    onTap: () => HomeShell.of(context).goTo(HomeShellState.tabProperties),
                  ),
                  StatCard(
                    label: 'Aktif kiracı',
                    value: '${store.activeTenants.length}',
                    icon: Icons.people,
                    onTap: () => HomeShell.of(context).goTo(HomeShellState.tabTenants),
                  ),
                  StatCard(
                    label: 'Beklenen kira',
                    caption: 'Aylık, aktif kiracılardan',
                    value: money(store.activeTenants.fold(0.0, (s, t) => s + t.rentAmount)),
                    icon: Icons.calendar_month,
                    color: AntColors.amber,
                  ),
                  StatCard(
                    label: 'Doluluk',
                    value: store.properties.isEmpty
                        ? '—'
                        : '%${(((store.properties.length - vacant) / store.properties.length) * 100).round()}',
                    icon: Icons.pie_chart_outline,
                  ),
                ]),
                if (overdue.isNotEmpty) ...[
                  SectionTitle('Geciken kiralar',
                      trailing: TextButton(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const OverdueScreen())),
                        child: const Text('Tümü'),
                      )),
                  Card(
                    child: Column(children: [
                      for (final p in overdue.take(4)) RentPeriodTile(period: p, showTenant: true),
                    ]),
                  ),
                ],
                if (upcoming.isNotEmpty) ...[
                  const SectionTitle('Bu ay beklenen ödemeler'),
                  Card(
                    child: Column(children: [
                      for (final p in upcoming.take(6)) RentPeriodTile(period: p, showTenant: true),
                    ]),
                  ),
                ],
                const SectionTitle('Son 6 ay'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 18, 16, 8),
                    child: IncomeExpenseChart(
                      months: Reports.lastMonths(store.transactions, today, 6),
                      height: 200,
                    ),
                  ),
                ),
                SectionTitle('Son hareketler',
                    trailing: TextButton(
                      onPressed: () => HomeShell.of(context).goTo(HomeShellState.tabTransactions),
                      child: const Text('Tümü'),
                    )),
                if (store.transactions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Henüz gelir veya gider kaydı yok.'),
                    ),
                  )
                else
                  Card(
                    child: Column(children: [
                      for (final t in store.transactions.take(5)) TxnTile(txn: t),
                    ]),
                  ),
              ]),
      ),
    );
  }
}
