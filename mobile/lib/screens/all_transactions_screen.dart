import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'transaction_detail_screen.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  List<dynamic> _transactions = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _filterType = 'semua'; // semua | masuk | keluar

  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final transactions = await ApiService.getTransactions();
      setState(() => _transactions = transactions);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    return _transactions.where((t) {
      if (_filterType != 'semua' && t['type'] != _filterType) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      final note = (t['note'] ?? '').toString().toLowerCase();
      final product = (t['product_name'] ?? '').toString().toLowerCase();
      final category = (t['category_name'] ?? '').toString().toLowerCase();
      return note.contains(q) || product.contains(q) || category.contains(q);
    }).toList();
  }

  Future<void> _openDetail(Map<String, dynamic> t) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: t)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Semua transaksi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari produk, kategori, atau catatan',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'semua', label: Text('Semua')),
                    ButtonSegment(value: 'masuk', label: Text('Kas masuk')),
                    ButtonSegment(value: 'keluar', label: Text('Kas keluar')),
                  ],
                  selected: {_filterType},
                  onSelectionChanged: (s) => setState(() => _filterType = s.first),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList(results)),
        ],
      ),
    );
  }

  Widget _buildList(List<dynamic> results) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return const Center(child: Text('Tidak ada transaksi yang cocok'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final t = results[index];
          final isMasuk = t['type'] == 'masuk';
          return ListTile(
            onTap: () => _openDetail(Map<String, dynamic>.from(t)),
            leading: Icon(
              isMasuk ? Icons.arrow_downward : Icons.arrow_upward,
              color: isMasuk ? Colors.green : Colors.red,
            ),
            title: Text(t['product_name'] ?? t['note'] ?? (isMasuk ? 'Kas masuk' : 'Kas keluar')),
            subtitle: Text(
              [
                t['transaction_date'],
                if (t['category_name'] != null) t['category_name'],
              ].join(' • '),
            ),
            trailing: Text(
              _currencyFormat.format(double.parse(t['amount'].toString())),
              style: TextStyle(color: isMasuk ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }
}
