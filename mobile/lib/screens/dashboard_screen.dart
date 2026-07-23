import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../services/invoice_service.dart';
import 'add_transaction_screen.dart';
import 'all_transactions_screen.dart';
import 'categories_screen.dart';
import 'login_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'transaction_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic> _transactions = [];
  bool _loading = true;
  String? _error;

  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await ApiService.getSummary();
      final transactions = await ApiService.getTransactions();
      setState(() {
        _summary = summary;
        _transactions = transactions;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BukuKas Pintar')),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Text('BukuKas Pintar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Laporan'),
              onTap: () async {
                Navigator.of(context).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Kategori'),
              onTap: () async {
                Navigator.of(context).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Produk & stok'),
              onTap: () async {
                Navigator.of(context).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProductsScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(context).pop();
                await _logout();
              },
            ),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );
          _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Catat transaksi'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

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
              ElevatedButton(onPressed: _loadData, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Transaksi terbaru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AllTransactionsScreen()),
                  );
                  _loadData();
                },
                child: const Text('Lihat semua'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada transaksi. Tekan "Catat transaksi" untuk mulai.')),
            )
          else
            ..._transactions.take(10).map((t) => _buildTransactionTile(t)),
        ],
      ),
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
            const Text('Ringkasan bulan ini', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
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
            _currencyFormat.format(value),
            style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Future<void> _shareInvoice(Map<String, dynamic> t) async {
    final text = await InvoiceService.buildInvoiceText(t);
    await Share.share(text);
  }

  Future<void> _openDetail(Map<String, dynamic> t) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: t)),
    );
    if (changed == true) _loadData();
  }

  Widget _buildTransactionTile(dynamic t) {
    final isMasuk = t['type'] == 'masuk';
    return ListTile(
      onTap: () => _openDetail(Map<String, dynamic>.from(t)),
      leading: Icon(
        isMasuk ? Icons.arrow_downward : Icons.arrow_upward,
        color: isMasuk ? Colors.green : Colors.red,
      ),
      title: Text(t['product_name'] ?? t['note'] ?? (isMasuk ? 'Kas masuk' : 'Kas keluar')),
      subtitle: Text(t['transaction_date']),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currencyFormat.format(double.parse(t['amount'].toString())),
            style: TextStyle(color: isMasuk ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Bagikan invoice',
            onPressed: () => _shareInvoice(Map<String, dynamic>.from(t)),
          ),
        ],
      ),
    );
  }
}
