import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

class CurrencyListItem extends StatelessWidget {
  final String currency;
  final String currencyName;
  final String flag;
  final double rate;
  final double change24h;
  final VoidCallback onTap;

  const CurrencyListItem({
    Key? key,
    required this.currency,
    required this.currencyName,
    required this.flag,
    required this.rate,
    required this.change24h,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Generate mock chart data for mini chart
    final List<FlSpot> spots = List.generate(
      20,
          (i) => FlSpot(
        i.toDouble(),
        rate * (1 + (math.sin(i * 0.5) * 0.03)),
      ),
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: onTap,
      leading: Text(
        flag,
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(
        currency,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(currencyName),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                rate.toStringAsFixed(5),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: change24h >= 0 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${change24h >= 0 ? '+' : ''}${change24h.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: change24h >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 60,
            height: 30,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: change24h >= 0 ? Colors.green : Colors.red,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                minY: spots.map((e) => e.y).reduce(math.min) * 0.98,
                maxY: spots.map((e) => e.y).reduce(math.max) * 1.02,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
