import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/ant_art.dart';
import 'dashboard_screen.dart';
import 'properties_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'tenants_screen.dart';
import 'transactions_screen.dart';

/// Alt sekmeler arasında geçişi sağlayan kabuk. Sekme değiştirmek için
/// alt ağaçtan `HomeShell.of(context).goTo(i)` çağrılabilir.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static HomeShellState of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>()!;

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const tabDashboard = 0;
  static const tabProperties = 1;
  static const tabTenants = 2;
  static const tabTransactions = 3;
  static const tabReports = 4;

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Özet'),
    (icon: Icons.apartment_outlined, selected: Icons.apartment, label: 'Mülkler'),
    (icon: Icons.people_outline, selected: Icons.people, label: 'Kiracılar'),
    (icon: Icons.receipt_long_outlined, selected: Icons.receipt_long, label: 'Gelir-Gider'),
    (icon: Icons.bar_chart_outlined, selected: Icons.bar_chart, label: 'Raporlar'),
  ];

  void goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    const pages = [
      DashboardScreen(),
      PropertiesScreen(),
      TenantsScreen(),
      TransactionsScreen(),
      ReportsScreen(),
    ];
    final body = IndexedStack(index: _index, children: pages);
    final wide = MediaQuery.sizeOf(context).width >= 840;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: goTo,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: AntLogo(size: 40),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: goTo,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// Her sekmenin uygulama çubuğunda yer alan profil/ayarlar düğmesi.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    final name = context.select<AuthService, String>((a) => a.currentUser?.name ?? '');
    final initials = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p.characters.first.toUpperCase())
        .join();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: 'Hesap ve ayarlar',
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        icon: CircleAvatar(
          radius: 17,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          child: Text(initials.isEmpty ? '?' : initials,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black87)),
        ),
      ),
    );
  }
}
