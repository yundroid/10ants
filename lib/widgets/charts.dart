import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/reports.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Aylık gelir (yeşil) ve gider (kırmızı) çubuk grafiği.
class IncomeExpenseChart extends StatelessWidget {
  const IncomeExpenseChart({super.key, required this.months, this.height = 220});
  final List<MonthTotals> months;
  final double height;

  @override
  Widget build(BuildContext context) {
    final inc = AntColors.income(context);
    final exp = AntColors.expense(context);
    final maxY = months.fold<double>(
        0, (m, e) => math.max(m, math.max(e.totals.income, e.totals.expense)));
    final top = maxY == 0 ? 1000.0 : maxY * 1.15;
    final barWidth = months.length > 8 ? 7.0 : 12.0;
    final labelStyle = Theme.of(context).textTheme.bodySmall;

    return Column(children: [
      SizedBox(
        height: height,
        child: BarChart(
          BarChartData(
            maxY: top,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: top / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
                getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                  '${rodIndex == 0 ? 'Gelir' : 'Gider'}\n${money(rod.toY)}',
                  TextStyle(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  interval: top / 4,
                  getTitlesWidget: (v, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(moneyShort(v), style: labelStyle),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= months.length) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(fmtMonthShort(months[i].month), style: labelStyle),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < months.length; i++)
                BarChartGroupData(x: i, barsSpace: 3, barRods: [
                  BarChartRodData(
                    toY: months[i].totals.income,
                    color: inc,
                    width: barWidth,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  BarChartRodData(
                    toY: months[i].totals.expense,
                    color: exp,
                    width: barWidth,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Legend(color: inc, label: 'Gelir'),
        const SizedBox(width: 18),
        _Legend(color: exp, label: 'Gider'),
      ]),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}
