import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/contact.dart';
import '../services/data_store.dart';
import '../services/rent_calculator.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/contact_buttons.dart';
import 'tenants_screen.dart';

/// Gecikmiş kiraların kiracı bazında gruplanmış listesi.
class OverdueScreen extends StatelessWidget {
  const OverdueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final overdue = store.overdue;
    final byTenant = <Tenant, List<RentPeriod>>{};
    for (final p in overdue) {
      byTenant.putIfAbsent(p.tenant, () => []).add(p);
    }
    final groups = byTenant.entries.toList()
      ..sort((a, b) =>
          RentCalculator.totalDebt(b.value).compareTo(RentCalculator.totalDebt(a.value)));

    return Scaffold(
      appBar: AppBar(title: const Text('Geciken kiralar')),
      body: overdue.isEmpty
          ? const EmptyState(
              title: 'Geciken kira yok',
              message: 'Tüm karıncalar erzağını zamanında getirmiş.',
            )
          : PageBody(children: [
              StatCard(
                label: 'Toplam gecikmiş alacak',
                value: money(RentCalculator.totalDebt(overdue)),
                icon: Icons.warning_amber_rounded,
                color: AntColors.expense(context),
                caption: '${byTenant.length} kiracı · ${overdue.length} dönem',
              ),
              for (final g in groups) ...[
                SectionTitle(
                  '${g.key.name} · ${store.propertyById(g.key.propertyId)?.name ?? ''}',
                  trailing: Text(money(RentCalculator.totalDebt(g.value)),
                      style: TextStyle(
                          color: AntColors.expense(context), fontWeight: FontWeight.w800)),
                ),
                Card(
                  child: Column(children: [
                    for (final p in g.value) RentPeriodTile(period: p),
                    const Divider(height: 1),
                    if (g.key.phone.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Row(children: [
                          Icon(Icons.phone_outlined,
                              size: 16, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(width: 6),
                          Text(g.key.phone, style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ),
                    ContactButtons(
                      tenant: g.key,
                      message: Contact.reminderMessage(
                          g.key, store.propertyById(g.key.propertyId), g.value),
                      onAddPhone: () => openTenantForm(context, tenant: g.key),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'İpucu: bir dönemin üzerine dokunarak hemen ödeme kaydedebilirsin.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ]),
    );
  }
}
