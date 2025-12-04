import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class XPHistoryChart extends StatelessWidget {
  final Map<String, int> history; // date -> total xp
  const XPHistoryChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(child: Text('No XP history yet', style: Theme.of(context).textTheme.bodySmall)),
      );
    }

    // Sort entries by date
    final sortedEntries = history.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    // Take last 7 days for better visibility if list is long
    final displayEntries = sortedEntries.length > 7 
        ? sortedEntries.sublist(sortedEntries.length - 7) 
        : sortedEntries;

    final spots = <FlSpot>[];
    for (var i = 0; i < displayEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), displayEntries[i].value.toDouble()));
    }

    final maxY = (displayEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2).clamp(10, double.infinity);

    return SizedBox(
      height: 200,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text('Last 7 Active Days', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 12),
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    minY: 0,
                    maxY: maxY.toDouble(),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) => Theme.of(context).colorScheme.surfaceContainerHighest,
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            return LineTooltipItem(
                              '${barSpot.y.toInt()} XP',
                              TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (val, meta) {
                        return Text(val.toInt().toString(), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline));
                      })),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (val, meta) {
                            final index = val.toInt();
                            if (index >= 0 && index < displayEntries.length) {
                              final dateStr = displayEntries[index].key;
                              try {
                                final date = DateTime.parse(dateStr);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    DateFormat('MM/dd').format(date),
                                    style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline),
                                  ),
                                );
                              } catch (_) {
                                return const SizedBox.shrink();
                              }
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        barWidth: 4,
                        color: Theme.of(context).colorScheme.primary,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Theme.of(context).colorScheme.surface,
                              strokeWidth: 2,
                              strokeColor: Theme.of(context).colorScheme.primary,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              Theme.of(context).colorScheme.primary.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
