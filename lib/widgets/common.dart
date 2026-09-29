import 'package:flutter/material.dart';

import '../services/rent_calculator.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'ant_art.dart';

/// Özet kartı. Metinler üç katmanla ayrışır:
/// - **başlık**: küçük, soluk, harf aralıklı (ne ölçüldüğü)
/// - **değer**: büyük, kalın, anlam rengiyle (asıl bilgi)
/// - **açıklama**: renkli hap içinde (ek bağlam)
/// Soldaki renkli şerit kartın anlamını (gelir/gider/uyarı) bir bakışta
/// gösterir.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    final tt = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: c),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          trUpper(label),
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(icon, size: 18, color: c),
                    ]),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800, color: c, height: 1.15)),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          caption!,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AntLogo(size: 72, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: tt.bodyMedium, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final RentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RentStatus.paid => AntColors.income(context),
      RentStatus.overdue => AntColors.expense(context),
      RentStatus.partial => AntColors.amber,
      RentStatus.upcoming => Theme.of(context).colorScheme.outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// Gelir için yeşil "+", gider için kırmızı "−" ile tutar gösterir.
class SignedAmount extends StatelessWidget {
  const SignedAmount(this.amount, {super.key, required this.income, this.style});
  final double amount;
  final bool income;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
        '${income ? '+' : '−'}${money(amount)}',
        style: (style ?? const TextStyle()).copyWith(
          color: income ? AntColors.income(context) : AntColors.expense(context),
          fontWeight: FontWeight.w700,
        ),
      );
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final cs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? cs.error : null,
    ));
}

String errorText(Object e) => switch (e) {
      ArgumentError(:final message) => '$message',
      StateError(:final message) => message,
      _ => e.toString(),
    };

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Sil',
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Tutar giriş alanı (₺). Türkçe biçimli ondalıkları ("1.250,50") kabul eder.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Tutar',
    this.required = true,
    this.allowZero = false,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final bool allowZero;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: '₺'),
        validator: (v) {
          if ((v ?? '').trim().isEmpty) return required ? '$label gerekli' : null;
          final a = parseAmount(v!);
          if (a == null) return 'Geçerli bir tutar girin';
          if (a < 0 || (!allowZero && a == 0)) return 'Tutar sıfırdan büyük olmalı';
          return null;
        },
      );
}

/// Dokununca tarih seçici açan alan.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.clearable = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: clearable && value != null
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () => onChanged(null))
                : const Icon(Icons.calendar_month_outlined),
          ),
          child: Text(value == null ? '—' : fmtDate(value!)),
        ),
      );
}

/// Formları dar ekranda tam genişlik, geniş ekranda ortalanmış gösterir.
class FormPage extends StatelessWidget {
  const FormPage({super.key, required this.title, required this.children, this.actions});
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final c in children)
                    Padding(padding: const EdgeInsets.only(bottom: 14), child: c),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Sayfa gövdesini geniş ekranlarda makul bir genişlikle sınırlar.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.padding});
  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: children,
          ),
        ),
      );
}
