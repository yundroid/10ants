import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/data_store.dart';
import '../services/rent_calculator.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'properties_screen.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  bool _showFormer = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final q = _query.toLowerCase();
    final list = store.tenants
        .where((t) => t.active != _showFormer)
        .where((t) =>
            q.isEmpty ||
            t.name.toLowerCase().contains(q) ||
            (store.propertyById(t.propertyId)?.name.toLowerCase().contains(q) ?? false))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kiracılarım'), actions: const [ProfileButton()]),
      floatingActionButton: store.properties.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'fab-tenants',
              onPressed: () => openTenantForm(context),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Kiracı ekle'),
            ),
      body: store.properties.isEmpty
          ? EmptyState(
              title: 'Önce bir mülk ekle',
              message: 'Kiracı eklemek için en az bir mülkün olmalı.',
              actionLabel: 'Mülk ekle',
              onAction: () => openPropertyForm(context),
            )
          : PageBody(children: [
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Kiracı veya mülk ara',
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                      value: false,
                      label: Text('Aktif (${store.tenants.where((t) => t.active).length})')),
                  ButtonSegment(
                      value: true,
                      label: Text('Ayrılanlar (${store.tenants.where((t) => !t.active).length})')),
                ],
                selected: {_showFormer},
                onSelectionChanged: (s) => setState(() => _showFormer = s.first),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyState(
                    title: _showFormer ? 'Ayrılan kiracı yok' : 'Kiracı bulunamadı',
                    message: _showFormer
                        ? 'Sözleşmesi biten kiracılar burada listelenir.'
                        : 'Yeni kiracı eklemek için sağ alttaki düğmeyi kullan.',
                  ),
                )
              else
                Card(child: Column(children: [for (final t in list) TenantTile(tenant: t)])),
            ]),
    );
  }
}

class TenantTile extends StatelessWidget {
  const TenantTile({super.key, required this.tenant});
  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final property = store.propertyById(tenant.propertyId);
    final debt = store.debtOf(tenant);
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (tenant.active ? cs.secondary : cs.outline).withValues(alpha: 0.25),
        child: Text(tenant.name.characters.first.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      title: Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
          '${property?.name ?? '—'} · ${money(tenant.rentAmount)}/ay · her ayın ${tenant.dueDay}\'i'),
      trailing: debt > 0
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Borç', style: Theme.of(context).textTheme.bodySmall),
                Text(money(debt),
                    style: TextStyle(
                        color: AntColors.expense(context), fontWeight: FontWeight.w800)),
              ],
            )
          : Icon(Icons.check_circle, color: AntColors.income(context)),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: tenant.id!))),
    );
  }
}

/// Bir kira döneminin satırı: dönem, vade, ödenen/kalan ve durum.
class RentPeriodTile extends StatelessWidget {
  const RentPeriodTile({super.key, required this.period, this.showTenant = false});
  final RentPeriod period;
  final bool showTenant;

  @override
  Widget build(BuildContext context) {
    final p = period;
    final store = context.read<DataStore>();
    final property = store.propertyById(p.tenant.propertyId);
    final sub = <String>[
      if (showTenant) property?.name ?? '',
      'Vade ${fmtDate(p.dueDate)}',
      if (p.status == RentStatus.overdue) '${p.daysLate} gün gecikti',
      if (p.paid > 0 && p.status != RentStatus.paid) 'Ödenen ${money(p.paid)}',
    ].where((s) => s.isNotEmpty).join(' · ');

    return ListTile(
      title: Text(showTenant ? '${p.tenant.name} — ${fmtPeriod(p.period)}' : fmtPeriod(p.period),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(money(p.status == RentStatus.paid ? p.paid : p.remaining),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          StatusChip(p.status),
        ],
      ),
      onTap: p.status == RentStatus.paid
          ? null
          : () => showPaymentDialog(context, p.tenant, period: p.period, amount: p.remaining),
    );
  }
}

class TenantDetailScreen extends StatelessWidget {
  const TenantDetailScreen({super.key, required this.tenantId});
  final int tenantId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final t = store.tenantById(tenantId);
    if (t == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Kiracı bulunamadı')));
    }
    final property = store.propertyById(t.propertyId);
    final ledger = store.ledgerOf(t);
    final debt = store.debtOf(t);
    final totalPaid = store
        .txnsOfTenant(tenantId)
        .where((x) => x.isRentPayment)
        .fold(0.0, (s, x) => s + x.amount);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.name),
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openTenantForm(context, tenant: t),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'moveout') {
                final ok = await confirm(context,
                    title: 'Kiracı çıkışı',
                    message:
                        '${t.name} bugün itibarıyla çıkmış olarak işaretlenecek. Kira takibi bugün sona erer; geçmiş borçlar görünmeye devam eder.',
                    confirmLabel: 'Çıkış yap',
                    destructive: false);
                if (ok) await store.saveTenant(t.copyWith(active: false, leaseEnd: store.today));
              } else if (v == 'reactivate') {
                await store.saveTenant(Tenant(
                  id: t.id,
                  userId: t.userId,
                  propertyId: t.propertyId,
                  name: t.name,
                  phone: t.phone,
                  email: t.email,
                  rentAmount: t.rentAmount,
                  dueDay: t.dueDay,
                  leaseStart: t.leaseStart,
                  deposit: t.deposit,
                  notes: t.notes,
                ));
              } else if (v == 'delete') {
                final ok = await confirm(context,
                    title: 'Kiracı silinsin mi?',
                    message:
                        'Kiracı kaydı silinir. Alınmış kira ödemeleri gelir kayıtlarında kalır.');
                if (!ok || !context.mounted) return;
                final nav = Navigator.of(context);
                await store.deleteTenant(tenantId);
                nav.pop();
              }
            },
            itemBuilder: (_) => [
              if (t.active)
                const PopupMenuItem(value: 'moveout', child: Text('Çıkış yaptı olarak işaretle'))
              else
                const PopupMenuItem(value: 'reactivate', child: Text('Tekrar aktif yap')),
              const PopupMenuItem(value: 'delete', child: Text('Kiracıyı sil')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-tenant-detail',
        onPressed: () {
          final open = ledger.where((p) => p.status != RentStatus.paid).toList();
          // En eski ödenmemiş dönemden başla.
          final target = open.isEmpty ? null : open.last;
          showPaymentDialog(context, t,
              period: target?.period, amount: target?.remaining ?? t.rentAmount);
        },
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Ödeme al'),
      ),
      body: PageBody(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(property?.name ?? '—',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (!t.active)
                  const Chip(label: Text('Ayrıldı'), visualDensity: VisualDensity.compact),
              ]),
              const SizedBox(height: 8),
              _InfoRow(Icons.payments_outlined, 'Aylık kira', money(t.rentAmount)),
              _InfoRow(Icons.event, 'Ödeme günü', 'Her ayın ${t.dueDay}. günü'),
              _InfoRow(Icons.play_circle_outline, 'Sözleşme başlangıcı', fmtDate(t.leaseStart)),
              if (t.leaseEnd != null)
                _InfoRow(Icons.stop_circle_outlined, 'Sözleşme bitişi', fmtDate(t.leaseEnd!)),
              if (t.deposit > 0) _InfoRow(Icons.lock_outline, 'Depozito', money(t.deposit)),
              if (t.phone.isNotEmpty) _InfoRow(Icons.phone_outlined, 'Telefon', t.phone),
              if (t.email.isNotEmpty) _InfoRow(Icons.email_outlined, 'E-posta', t.email),
              if (t.notes.isNotEmpty) _InfoRow(Icons.notes, 'Not', t.notes),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: StatCard(
              label: 'Gecikmiş borç',
              value: money(debt),
              icon: Icons.warning_amber_rounded,
              color: debt > 0 ? AntColors.expense(context) : AntColors.income(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              label: 'Toplam ödenen',
              value: money(totalPaid),
              icon: Icons.check_circle_outline,
              color: AntColors.income(context),
            ),
          ),
        ]),
        const SectionTitle('Kira dökümü'),
        if (ledger.isEmpty)
          const Card(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Sözleşme henüz başlamadı.')))
        else
          Card(child: Column(children: [for (final p in ledger) RentPeriodTile(period: p)])),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 10),
          SizedBox(
              width: 150,
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

/// Kira tahsilatı iletişim kutusu.
Future<void> showPaymentDialog(
  BuildContext context,
  Tenant tenant, {
  String? period,
  double? amount,
}) async {
  final store = context.read<DataStore>();
  final ledgerPeriods = store.ledgerOf(tenant).map((p) => p.period).toList();
  // Gelecek ay için peşin ödeme seçeneği.
  final next = periodKey(DateTime(store.today.year, store.today.month + 1));
  final periods = {if (tenant.active) next, ...ledgerPeriods}.toList();
  var selected = period ?? (periods.isEmpty ? periodKey(store.today) : periods.last);
  if (!periods.contains(selected)) periods.insert(0, selected);
  final amountCtl = TextEditingController(text: amountInput(amount ?? tenant.rentAmount));
  final noteCtl = TextEditingController();
  var date = store.today;
  final form = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Ödeme al'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(tenant.name),
                  subtitle: Text('Aylık kira ${money(tenant.rentAmount)}'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Kira dönemi'),
                  items: [
                    for (final p in periods)
                      DropdownMenuItem(value: p, child: Text(fmtPeriod(p))),
                  ],
                  onChanged: (v) => setState(() => selected = v ?? selected),
                ),
                const SizedBox(height: 12),
                AmountField(controller: amountCtl, label: 'Tutar'),
                const SizedBox(height: 12),
                DateField(
                    label: 'Ödeme tarihi',
                    value: date,
                    onChanged: (d) => setState(() => date = d ?? date)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteCtl,
                  decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)'),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              try {
                await store.recordRentPayment(
                  tenant: tenant,
                  period: selected,
                  amount: parseAmount(amountCtl.text)!,
                  date: date,
                  description: noteCtl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) showSnack(context, 'Ödeme kaydedildi');
              } catch (e) {
                if (ctx.mounted) showSnack(ctx, errorText(e), error: true);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
  amountCtl.dispose();
  noteCtl.dispose();
}

void openTenantForm(BuildContext context, {Tenant? tenant, int? propertyId}) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => TenantFormScreen(tenant: tenant, propertyId: propertyId),
  ));
}

class TenantFormScreen extends StatefulWidget {
  const TenantFormScreen({super.key, this.tenant, this.propertyId});
  final Tenant? tenant;
  final int? propertyId;

  @override
  State<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends State<TenantFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Tenant? t = widget.tenant;
  late final _name = TextEditingController(text: t?.name);
  late final _phone = TextEditingController(text: t?.phone);
  late final _email = TextEditingController(text: t?.email);
  late final _rent = TextEditingController(text: t == null ? '' : amountInput(t!.rentAmount));
  late final _deposit =
      TextEditingController(text: t == null || t!.deposit == 0 ? '' : amountInput(t!.deposit));
  late final _dueDay = TextEditingController(text: '${t?.dueDay ?? 1}');
  late final _notes = TextEditingController(text: t?.notes);
  late int? _propertyId = t?.propertyId ?? widget.propertyId;
  late DateTime _leaseStart = t?.leaseStart ?? dateOnly(DateTime.now());
  late DateTime? _leaseEnd = t?.leaseEnd;
  late bool _active = t?.active ?? true;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _rent, _deposit, _dueDay, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = context.read<DataStore>();
    setState(() => _busy = true);
    try {
      await store.saveTenant(Tenant(
        id: t?.id,
        userId: store.userId,
        propertyId: _propertyId!,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        rentAmount: parseAmount(_rent.text)!,
        dueDay: int.parse(_dueDay.text),
        leaseStart: _leaseStart,
        leaseEnd: _leaseEnd,
        deposit: parseAmount(_deposit.text) ?? 0,
        notes: _notes.text.trim(),
        active: _active,
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
    final store = context.watch<DataStore>();
    return Form(
      key: _form,
      child: FormPage(
        title: t == null ? 'Yeni kiracı' : 'Kiracıyı düzenle',
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Ad soyad'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Ad soyad gerekli' : null,
          ),
          DropdownButtonFormField<int>(
            initialValue: _propertyId,
            decoration: const InputDecoration(labelText: 'Mülk'),
            items: [
              for (final p in store.properties)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            validator: (v) => v == null ? 'Mülk seçin' : null,
            onChanged: (v) => setState(() => _propertyId = v),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: AmountField(controller: _rent, label: 'Aylık kira')),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _dueDay,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ödeme günü', helperText: '1-31'),
                validator: (v) {
                  final d = int.tryParse(v ?? '');
                  return d == null || d < 1 || d > 31 ? '1-31 arası' : null;
                },
              ),
            ),
          ]),
          DateField(
            label: 'Sözleşme başlangıcı',
            value: _leaseStart,
            onChanged: (d) => setState(() => _leaseStart = d ?? _leaseStart),
          ),
          DateField(
            label: 'Sözleşme bitişi (isteğe bağlı)',
            value: _leaseEnd,
            clearable: true,
            onChanged: (d) => setState(() => _leaseEnd = d),
          ),
          AmountField(
              controller: _deposit, label: 'Depozito (isteğe bağlı)', required: false, allowZero: true),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefon', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration:
                const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email_outlined)),
          ),
          TextFormField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notlar'),
          ),
          if (t != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktif kiracı'),
              subtitle: const Text('Kapatırsan kira takibi durur'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Kaydet')),
        ],
      ),
    );
  }
}
