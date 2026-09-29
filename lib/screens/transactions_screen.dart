import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/data_store.dart';
import '../services/reports.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

enum _TypeFilter { all, income, expense }

class _TransactionsScreenState extends State<TransactionsScreen> {
  _TypeFilter _type = _TypeFilter.all;
  int? _propertyId;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _allTime = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final list = store.transactions.where((t) {
      if (_type == _TypeFilter.income && t.type != TxType.income) return false;
      if (_type == _TypeFilter.expense && t.type != TxType.expense) return false;
      if (_propertyId != null && t.propertyId != _propertyId) return false;
      if (!_allTime && (t.date.year != _month.year || t.date.month != _month.month)) {
        return false;
      }
      return true;
    }).toList();
    final totals = Totals.of(list);

    return Scaffold(
      appBar: AppBar(title: const Text('Gelir & Gider'), actions: const [ProfileButton()]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-transactions',
        onPressed: () => _addMenu(context),
        icon: const Icon(Icons.add),
        label: const Text('Kayıt ekle'),
      ),
      body: PageBody(children: [
        Row(children: [
          IconButton(
            onPressed: _allTime
                ? null
                : () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              _allTime ? 'Tüm zamanlar' : fmtMonthYear(_month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: _allTime
                ? null
                : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
            icon: const Icon(Icons.chevron_right),
          ),
          FilterChip(
            label: const Text('Tümü'),
            selected: _allTime,
            onSelected: (v) => setState(() => _allTime = v),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<_TypeFilter>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _TypeFilter.all, label: Text('Hepsi')),
              ButtonSegment(value: _TypeFilter.income, label: Text('Gelir')),
              ButtonSegment(value: _TypeFilter.expense, label: Text('Gider')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          DropdownButton<int?>(
            value: _propertyId,
            hint: const Text('Tüm mülkler'),
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tüm mülkler')),
              for (final p in store.properties) DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _propertyId = v),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: StatCard(
                  label: 'Gelir',
                  value: money(totals.income),
                  icon: Icons.arrow_downward,
                  color: AntColors.income(context))),
          const SizedBox(width: 8),
          Expanded(
              child: StatCard(
                  label: 'Gider',
                  value: money(totals.expense),
                  icon: Icons.arrow_upward,
                  color: AntColors.expense(context))),
          const SizedBox(width: 8),
          Expanded(
              child: StatCard(label: 'Net', value: money(totals.net), icon: Icons.balance)),
        ]),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: EmptyState(
              title: 'Bu aralıkta kayıt yok',
              message: 'Kira tahsilatı, aidat, tamir, vergi gibi kalemleri ekleyerek takibe başla.',
            ),
          )
        else
          Card(child: Column(children: [for (final t in list) TxnTile(txn: t)])),
      ]),
    );
  }

  void _addMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.add_circle_outline, color: AntColors.income(context)),
            title: const Text('Gelir ekle'),
            subtitle: const Text('Kira tahsilatı, depozito, diğer gelir'),
            onTap: () {
              Navigator.pop(ctx);
              openTxnForm(context, type: TxType.income, propertyId: _propertyId);
            },
          ),
          ListTile(
            leading: Icon(Icons.remove_circle_outline, color: AntColors.expense(context)),
            title: const Text('Gider ekle'),
            subtitle: const Text('Aidat, tamir, vergi, sigorta…'),
            onTap: () {
              Navigator.pop(ctx);
              openTxnForm(context, type: TxType.expense, propertyId: _propertyId);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn, this.showProperty = true});
  final Txn txn;
  final bool showProperty;

  @override
  Widget build(BuildContext context) {
    final store = context.read<DataStore>();
    final income = txn.type == TxType.income;
    final c = income ? AntColors.income(context) : AntColors.expense(context);
    final property = store.propertyById(txn.propertyId);
    final tenant = store.tenantById(txn.tenantId);
    final parts = <String>[
      fmtDate(txn.date),
      if (showProperty) property?.name ?? 'Genel',
      if (tenant != null) tenant.name,
      if (txn.period != null && txn.category == TxCategories.rent) fmtPeriod(txn.period!),
      if (txn.description.isNotEmpty) txn.description,
    ];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: c.withValues(alpha: 0.14),
        child: Icon(income ? Icons.south_west : Icons.north_east, color: c, size: 20),
      ),
      title: Text(txn.category, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(parts.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: SignedAmount(txn.amount, income: income),
      onTap: () => openTxnForm(context, txn: txn),
    );
  }
}

void openTxnForm(BuildContext context, {Txn? txn, TxType? type, int? propertyId}) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => TxnFormScreen(txn: txn, type: type, propertyId: propertyId),
  ));
}

class TxnFormScreen extends StatefulWidget {
  const TxnFormScreen({super.key, this.txn, this.type, this.propertyId});
  final Txn? txn;
  final TxType? type;
  final int? propertyId;

  @override
  State<TxnFormScreen> createState() => _TxnFormScreenState();
}

class _TxnFormScreenState extends State<TxnFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Txn? x = widget.txn;
  late TxType _type = x?.type ?? widget.type ?? TxType.expense;
  late String _category = x?.category ?? TxCategories.of(_type).first;
  late int? _propertyId = x?.propertyId ?? widget.propertyId;
  late int? _tenantId = x?.tenantId;
  late String? _period = x?.period;
  late DateTime _date = x?.date ?? dateOnly(DateTime.now());
  late final _amount = TextEditingController(text: x == null ? '' : amountInput(x!.amount));
  late final _desc = TextEditingController(text: x?.description);
  bool _busy = false;

  bool get _isRent => _type == TxType.income && _category == TxCategories.rent;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final store = context.read<DataStore>();
    setState(() => _busy = true);
    try {
      await store.saveTxn(Txn(
        id: x?.id,
        userId: store.userId,
        propertyId: _propertyId,
        tenantId: _tenantId,
        type: _type,
        category: _category,
        amount: parseAmount(_amount.text)!,
        date: _date,
        period: _isRent ? (_period ?? periodKey(_date)) : null,
        description: _desc.text.trim(),
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(context,
        title: 'Kayıt silinsin mi?', message: '${x!.category} — ${money(x!.amount)}');
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    await context.read<DataStore>().deleteTxn(x!.id!);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<DataStore>();
    final categories = {...TxCategories.of(_type), _category}.toList();
    final tenants = store.tenants
        .where((t) => _propertyId == null || t.propertyId == _propertyId)
        .toList();
    if (_tenantId != null && !tenants.any((t) => t.id == _tenantId)) _tenantId = null;

    // Kira dönemi seçenekleri: son 12 ay + gelecek ay.
    final now = store.today;
    final periods = [
      for (var i = 1; i >= -12; i--) periodKey(DateTime(now.year, now.month + i)),
    ];
    final effectivePeriod = _period ?? periodKey(_date);
    if (!periods.contains(effectivePeriod)) periods.add(effectivePeriod);

    return Form(
      key: _form,
      child: FormPage(
        title: x == null
            ? (_type == TxType.income ? 'Gelir ekle' : 'Gider ekle')
            : 'Kaydı düzenle',
        actions: [
          if (x != null)
            IconButton(tooltip: 'Sil', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
        children: [
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.income, label: Text('Gelir'), icon: Icon(Icons.south_west)),
              ButtonSegment(value: TxType.expense, label: Text('Gider'), icon: Icon(Icons.north_east)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _category = TxCategories.of(_type).first;
            }),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('cat-$_type'),
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          AmountField(controller: _amount),
          DateField(label: 'Tarih', value: _date, onChanged: (d) => setState(() => _date = d ?? _date)),
          DropdownButtonFormField<int?>(
            initialValue: _propertyId,
            decoration: const InputDecoration(labelText: 'Mülk'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Genel (mülkten bağımsız)')),
              for (final p in store.properties) DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            validator: (v) => _isRent && v == null ? 'Kira için mülk seçin' : null,
            onChanged: (v) => setState(() => _propertyId = v),
          ),
          if (_type == TxType.income)
            DropdownButtonFormField<int?>(
              key: ValueKey('tenant-$_propertyId'),
              initialValue: _tenantId,
              decoration: const InputDecoration(labelText: 'Kiracı'),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                for (final t in tenants) DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              validator: (v) => _isRent && v == null ? 'Kira için kiracı seçin' : null,
              onChanged: (v) => setState(() {
                _tenantId = v;
                final t = store.tenantById(v);
                if (t != null) {
                  _propertyId = t.propertyId;
                  if (_amount.text.isEmpty && _isRent) _amount.text = amountInput(t.rentAmount);
                }
              }),
            ),
          if (_isRent)
            DropdownButtonFormField<String>(
              key: ValueKey('period-$effectivePeriod'),
              initialValue: effectivePeriod,
              decoration: const InputDecoration(
                  labelText: 'Kira dönemi', helperText: 'Bu ödeme hangi ayın kirası?'),
              items: [for (final p in periods) DropdownMenuItem(value: p, child: Text(fmtPeriod(p)))],
              onChanged: (v) => setState(() => _period = v),
            ),
          TextFormField(
            controller: _desc,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Açıklama'),
          ),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Kaydet')),
        ],
      ),
    );
  }
}
