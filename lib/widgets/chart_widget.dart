import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class ChartWidget extends StatefulWidget {
  final List<Transaction> transactions;

  const ChartWidget({super.key, required this.transactions});

  @override
  State<ChartWidget> createState() => _ChartWidgetState();
}

class _ChartWidgetState extends State<ChartWidget>
    with SingleTickerProviderStateMixin {
  int _selectedChartIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onChartChanged(int index) {
    setState(() {
      _selectedChartIndex = index;
    });
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
                value: 0, label: Text('Bar'), icon: Icon(Icons.bar_chart)),
            ButtonSegment(
                value: 1, label: Text('Pie'), icon: Icon(Icons.pie_chart)),
            ButtonSegment(
                value: 2, label: Text('Line'), icon: Icon(Icons.show_chart)),
          ],
          selected: {_selectedChartIndex},
          onSelectionChanged: (Set<int> newSelection) {
            _onChartChanged(newSelection.first);
          },
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: SizedBox(
            key: ValueKey(_selectedChartIndex),
            height: 300,
            child: Card(
              elevation: 3,
              shadowColor: Colors.red.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildSelectedChart(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedChart() {
    if (widget.transactions.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    switch (_selectedChartIndex) {
      case 0:
        return _buildBarChart();
      case 1:
        return _buildPieChart();
      case 2:
        return _buildLineChart();
      default:
        return _buildBarChart();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  double _niceInterval(double maxY, {int maxLabels = 6}) {
    if (maxY <= 0) return 1;
    final candidates = <double>[];
    for (int exp = 0; exp <= 7; exp++) {
      final pow = Math.pow(10, exp).toDouble();
      candidates.addAll([1 * pow, 2 * pow, 5 * pow]);
    }
    for (final c in candidates) {
      if ((maxY / c) <= maxLabels) return c;
    }
    return (maxY / maxLabels).ceilToDouble();
  }

  double _ceilToInterval(double value, double interval) {
    return (value / interval).ceil() * interval;
  }

  // ── Bar Chart ─────────────────────────────────────────────────────────────

  Widget _buildBarChart() {
    final categoryTotals = <String, double>{};
    final categoryDates = <String, DateTime>{};

    for (var t in widget.transactions) {
      if (t.type == 'expense') {
        categoryTotals[t.category] =
            (categoryTotals[t.category] ?? 0) + t.amount;
        if (!categoryDates.containsKey(t.category) ||
            t.date.isAfter(categoryDates[t.category]!)) {
          categoryDates[t.category] = t.date;
        }
      }
    }

    if (categoryTotals.isEmpty) {
      return const Center(child: Text('No expense data'));
    }

    final entries = categoryTotals.entries.toList();
    final rawMax = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final interval = _niceInterval(rawMax);
    final maxY = _ceilToInterval(rawMax, interval);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      tooltipRoundedRadius: 8,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final category = entries[group.x.toInt()].key;
                        final amount = entries[group.x.toInt()].value;
                        return BarTooltipItem(
                          '$category\nTk ${amount.toStringAsFixed(0)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    final animatedValue = data.value * _animation.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: animatedValue,
                          width: 32,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.shade300,
                              Colors.red.shade600,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('');
                          String label;
                          if (value >= 1000) {
                            label =
                                'Tk ${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
                          } else {
                            label = 'Tk ${value.toInt()}';
                          }
                          return Text(
                            label,
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= entries.length) {
                            return const Text('');
                          }
                          final category = entries[value.toInt()].key;
                          final date = categoryDates[category];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (date != null)
                                  Text(
                                    DateFormat('MMM dd').format(date),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap bars to see details',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Pie Chart ─────────────────────────────────────────────────────────────

  Widget _buildPieChart() {
    final categoryTotals = <String, double>{};

    for (var t in widget.transactions) {
      if (t.type == 'expense') {
        categoryTotals[t.category] =
            (categoryTotals[t.category] ?? 0) + t.amount;
      }
    }

    if (categoryTotals.isEmpty) {
      return const Center(child: Text('No expense data'));
    }

    final total = categoryTotals.values.fold(0.0, (a, b) => a + b);

    final colors = [
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.blue,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    final entries = categoryTotals.entries.toList();
    int touchedIndex = -1;

    return StatefulBuilder(
      builder: (context, setStateLocal) {
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Pie Chart (flex 6) ──────────────────────────────────
                Expanded(
                  flex: 6,
                  child: PieChart(
                    PieChartData(
                      startDegreeOffset: -90 + (360 * (1 - _animation.value)),
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, response) {
                          setStateLocal(() {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sections: entries.asMap().entries.map((e) {
                        final index = e.key;
                        final entry = e.value;
                        final pct = entry.value / total * 100;
                        final isTouched = index == touchedIndex;
                        final color = colors[index % colors.length];
                        return PieChartSectionData(
                          value: entry.value,
                          title: isTouched
                              ? '${pct.toStringAsFixed(1)}%'
                              : '${pct.toStringAsFixed(1)}%',
                          color: isTouched ? color : color.withOpacity(0.85),
                          radius: isTouched ? 85 : 70,
                          titleStyle: TextStyle(
                            fontSize: isTouched ? 12 : 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black45, blurRadius: 4),
                            ],
                          ),
                          borderSide: isTouched
                              ? const BorderSide(
                                  color: Colors.white, width: 3)
                              : BorderSide.none,
                        );
                      }).toList(),
                      sectionsSpace: 3,
                      centerSpaceRadius: 30,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // ── Legend (flex 4) ─────────────────────────────────────
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: entries.asMap().entries.map((e) {
                        final index = e.key;
                        final entry = e.value;
                        final pct =
                            (entry.value / total * 100).toStringAsFixed(1);
                        final color = colors[index % colors.length];
                        final isTouched = index == touchedIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: EdgeInsets.symmetric(
                            horizontal: isTouched ? 6 : 3,
                            vertical: isTouched ? 3 : 2,
                          ),
                          decoration: BoxDecoration(
                            color: isTouched
                                ? color.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: isTouched
                                ? Border.all(
                                    color: color.withOpacity(0.4), width: 1)
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Color dot
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isTouched ? 12 : 10,
                                height: isTouched ? 12 : 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 5),
                              // Text column — Expanded so it never overflows
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: TextStyle(
                                        fontSize: isTouched ? 12 : 11,
                                        fontWeight: isTouched
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    Text(
                                      'Tk ${entry.value.toStringAsFixed(0)}  •  $pct%',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isTouched
                                            ? color
                                            : Colors.grey[600],
                                        fontWeight: isTouched
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Line Chart ────────────────────────────────────────────────────────────

  Widget _buildLineChart() {
    final Map<DateTime, double> dailyExpenses = {};

    for (var t in widget.transactions) {
      if (t.type == 'expense') {
        final date = DateTime(t.date.year, t.date.month, t.date.day);
        dailyExpenses[date] = (dailyExpenses[date] ?? 0) + t.amount;
      }
    }

    if (dailyExpenses.isEmpty) {
      return const Center(child: Text('No expense data'));
    }

    final sortedDates = dailyExpenses.keys.toList()..sort();
    final spots = sortedDates.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), dailyExpenses[entry.value]!);
    }).toList();

    final rawMax = dailyExpenses.values.reduce((a, b) => a > b ? a : b);
    final interval = _niceInterval(rawMax);
    final maxY = _ceilToInterval(rawMax, interval);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final visibleCount =
            (_animation.value * spots.length).ceil().clamp(1, spots.length);
        final animatedSpots = spots.sublist(0, visibleCount);

        return LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey[300],
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  interval: interval,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const Text('');
                    String label;
                    if (value >= 1000) {
                      label =
                          'Tk ${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
                    } else {
                      label = 'Tk ${value.toInt()}';
                    }
                    return Text(label, style: const TextStyle(fontSize: 10));
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  interval: sortedDates.length > 7
                      ? (sortedDates.length / 5).ceilToDouble()
                      : 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= sortedDates.length) {
                      return const Text('');
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('MMM dd').format(sortedDates[index]),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
                left: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                tooltipPadding: const EdgeInsets.all(8),
                tooltipRoundedRadius: 8,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final date = sortedDates[spot.x.toInt()];
                    return LineTooltipItem(
                      '${DateFormat('MMM dd').format(date)}\nTk ${spot.y.toStringAsFixed(0)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: animatedSpots,
                isCurved: true,
                color: Colors.red.shade400,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: Colors.red.shade600,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade200.withOpacity(0.3),
                      Colors.red.shade100.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Minimal dart:math shim so we don't need an extra import
class Math {
  static num pow(num x, num exponent) {
    num result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= x;
    }
    return result;
  }
}