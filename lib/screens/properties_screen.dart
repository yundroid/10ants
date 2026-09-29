import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/data_store.dart';
import '../services/reports.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'tenants_screen.dart';
import 'transactions_screen.dart';

IconData propertyIcon(PropertyType t) => switch (t) {
      PropertyType.daire => Icons.apartment,
      PropertyType.mustakil => Icons.house,
      PropertyType.villa => Icons.villa,
      PropertyType.dukkan => Icons.storefront,
      PropertyType.ofis => Icons.business_center,
      PropertyType.arsa => Icons.landscape,
      PropertyType.diger => Icons.home_work,
    };

class PropertiesScreen extends StatelessWidget {
  const PropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final props = store.properties;
    return Scaffold(
      appBar: AppBar(title: const Text('Mülklerim'), actions: const [ProfileButton()]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-properties',
        onPressed: () => openPropertyForm(context),
        icon: const Icon(Icons.add_home_outlined),
        label: const Text('Mülk ekle'),
      ),
      body: props.isEmpty
          ? EmptyState(
              title: 'Henüz mülk yok',
              message: 'Daire, ev, dükkan… Kiraya verdiğin her yeri buraya ekle.',
              actionLabel: 'Mülk ekle',
              onAction: () => openPropertyForm(context),
            )
          : PageBody(children: [
              for (final p in props)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PropertyCard(property: p),
                ),
            ]),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});
  final Property property;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final tenants = store.tenantsOf(property.id!).where((t) => t.active).toList();
    final totals = Reports.forYear(store.txnsOfProperty(property.id!), store.today.year);
    final debt = tenants.fold(0.0, (s, t) => s + store.debtOf(t));
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PropertyDetailScreen(propertyId: property.id!))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Icon(propertyIcon(property.type), color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(property.name,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    [property.type.label, if (property.address.isNotEmpty) property.address]
                        .join(' · '),
                    style: tt.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              _OccupancyBadge(vacant: tenants.isEmpty),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              _Mini(label: '${store.today.year} gelir', value: money(totals.income),
                  color: AntColors.income(context)),
              _Mini(label: 'Gider', value: money(totals.expense),
                  color: AntColors.expense(context)),
              _Mini(label: 'Net', value: money(totals.net)),
            ]),
            if (tenants.isNotEmpty) ...[
              const Divider(height: 22),
              Row(children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(tenants.map((t) => t.name).join(', '),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (debt > 0)
                  Text('Borç: ${money(debt)}',
                      style: TextStyle(
                          color: AntColors.expense(context), fontWeight: FontWeight.w700)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _OccupancyBadge extends StatelessWidget {
  const _OccupancyBadge({required this.vacant});
  final bool vacant;

  @override
  Widget build(BuildContext context) {
    final c = vacant ? AntColors.amber : AntColors.income(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(vacant ? 'Boş' : 'Kirada',
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
      );
}

class PropertyDetailScreen extends StatelessWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});
  final int propertyId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final p = store.propertyById(propertyId);
    if (p == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Mülk bulunamadı')));
    }
    final tenants = store.tenantsOf(propertyId);
    final txns = store.txnsOfProperty(propertyId);
    final allTime = Totals.of(txns);
    final thisYear = Reports.forYear(txns, store.today.year);

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openPropertyForm(context, property: p),
          ),
          IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirm(
                context,
                title: 'Mülk silinsin mi?',
                message:
                    '"${p.name}" ile birlikte bu mülke ait ${tenants.length} kiracı ve ${txns.length} gelir/gider kaydı da silinecek. Bu işlem geri alınamaz.',
              );
              if (!ok || !context.mounted) return;
              final nav = Navigator.of(context);
              await store.deleteProperty(propertyId);
              nav.pop();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-property-detail',
        onPressed: () => openTxnForm(context, propertyId: propertyId, type: TxType.expense),
        icon: const Icon(Icons.add),
        label: const Text('Gider ekle'),
      ),
      body: PageBody(children: [
        Card(
          child: ListTile(
            leading: Icon(propertyIcon(p.type)),
            title: Text(p.type.label),
            subtitle: Text([
              if (p.address.isNotEmpty) p.address,
              if (p.notes.isNotEmpty) p.notes,
            ].join('\n').ifEmpty('Adres girilmemiş')),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: StatCard(
                  label: '${store.today.year} net',
                  value: money(thisYear.net),
                  icon: Icons.account_balance_wallet_outlined)),
          const SizedBox(width: 8),
          Expanded(
              child: StatCard(
                  label: 'Toplam net',
                  value: money(allTime.net),
                  icon: Icons.account_balance_outlined,
                  caption: 'Gelir ${money(allTime.income)}')),
        ]),
        SectionTitle('Kiracılar',
            trailing: TextButton.icon(
              onPressed: () => openTenantForm(context, propertyId: propertyId),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Ekle'),
            )),
        if (tenants.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(20), child: Text('Bu mülk şu an boş.')))
        else
          Card(
            child: Column(children: [for (final t in tenants) TenantTile(tenant: t)]),
          ),
        const SectionTitle('Gelir & gider hareketleri'),
        if (txns.isEmpty)
          const Card(
              child: Padding(padding: EdgeInsets.all(20), child: Text('Kayıt yok.')))
        else
          Card(child: Column(children: [for (final t in txns) TxnTile(txn: t, showProperty: false)])),
      ]),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

void openPropertyForm(BuildContext context, {Property? property}) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PropertyFormScreen(property: property),
  ));
}

class PropertyFormScreen extends StatefulWidget {
  const PropertyFormScreen({super.key, this.property});
  final Property? property;

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.property?.name);
  late final _address = TextEditingController(text: widget.property?.address);
  late final _notes = TextEditingController(text: widget.property?.notes);
  late PropertyType _type = widget.property?.type ?? PropertyType.daire;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = context.read<DataStore>();
    setState(() => _busy = true);
    try {
      await store.saveProperty(Property(
        id: widget.property?.id,
        userId: store.userId,
        name: _name.text.trim(),
        address: _address.text.trim(),
        type: _type,
        notes: _notes.text.trim(),
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: FormPage(
        title: widget.property == null ? 'Yeni mülk' : 'Mülkü düzenle',
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Mülk adı', hintText: 'Örn. Moda 3+1, Kadıköy Dükkan'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Mülk adı gerekli' : null,
          ),
          DropdownButtonFormField<PropertyType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tür'),
            items: [
              for (final t in PropertyType.values)
                DropdownMenuItem(
                  value: t,
                  child: Row(children: [
                    Icon(propertyIcon(t), size: 20),
                    const SizedBox(width: 10),
                    Text(t.label),
                  ]),
                ),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          TextFormField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Adres'),
          ),
          TextFormField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notlar'),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
