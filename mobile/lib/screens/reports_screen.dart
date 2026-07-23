import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _summary;
  List<dynamic> _daily = [];
  DateTime _rangeStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _rangeEnd = DateTime.now();

  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dateFormat = DateFormat('d/M');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final summary = await ApiService.getSummary(startDate: _iso(_rangeStart), endDate: _iso(_rangeEnd));
      final daily = await ApiService.getDaily(startDate: _iso(_rangeStart), endDate: _iso(_rangeEnd));
      setState(() {
        _summary = summary;
        _daily = daily;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat laporan: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  // Gabungkan data harian dari backend (per type) jadi map per tanggal: {masuk, keluar}
  Map<String, Map<String, double>> get _byDate {
    final map = <String, Map<String, double>>{};
    for (final row in _daily) {
      final date = row['transaction_date'].toString().substring(0, 10);
      final type = row['type'];
      final total = double.tryParse(row['total'].toString()) ?? 0;
      map.putIfAbsent(date, () => {'masuk': 0, 'keluar': 0});
      map[date]![type] = total;
    }
    return map;
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
    );
    if (picked != null) {
      setState(() {
        _rangeStart = picked.start;
        _rangeEnd = picked.end;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final byDate = _byDate;
    final sortedDates = byDate.keys.toList()..sort();
    final maxValue = sortedDates.fold<double>(
      0,
      (max, d) => [max, byDate[d]!['masuk'] ?? 0, byDate[d]!['keluar'] ?? 0].reduce((a, b) => a > b ? a : b),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: _pickRange),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${DateFormat('d MMM yyyy').format(_rangeStart)} — ${DateFormat('d MMM yyyy').format(_rangeEnd)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  const Text('Kas masuk vs keluar per hari', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _legend(),
                  const SizedBox(height: 12),
                  sortedDates.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('Belum ada transaksi di periode ini')),
                        )
                      : SizedBox(
                          height: 260,
                          child: BarChart(
                            BarChartData(
                              maxY: maxValue == 0 ? 100 : maxValue * 1.2,
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      _currencyFormat.format(rod.toY),
                                      const TextStyle(color: Colors.white, fontSize: 12),
                                    );
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index < 0 || index >= sortedDates.length) return const SizedBox();
                                      // Kalau data terlalu banyak, tampilkan label seperlunya saja
                                      if (sortedDates.length > 10 && index % (sortedDates.length ~/ 8) != 0) {
                                        return const SizedBox();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          _dateFormat.format(DateTime.parse(sortedDates[index])),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(sortedDates.length, (i) {
                                final d = sortedDates[i];
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(toY: byDate[d]!['masuk'] ?? 0, color: Colors.green, width: 6),
                                    BarChartRodData(toY: byDate[d]!['keluar'] ?? 0, color: Colors.red, width: 6),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _legend() {
    return Row(
      children: [
        Container(width: 10, height: 10, color: Colors.green),
        const SizedBox(width: 4),
        const Text('Kas masuk', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 16),
        Container(width: 10, height: 10, color: Colors.red),
        const SizedBox(width: 4),
        const Text('Kas keluar', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final masuk = _summary?['masuk'] ?? 0;
    final keluar = _summary?['keluar'] ?? 0;
    final saldo = _summary?['saldo'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryRow('Kas masuk', masuk, Colors.green),
            _summaryRow('Kas keluar', keluar, Colors.red),
            const Divider(),
            _summaryRow('Saldo', saldo, Colors.blue, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, dynamic value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            _currencyFormat.format(value is num ? value : double.tryParse(value.toString()) ?? 0),
            style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
