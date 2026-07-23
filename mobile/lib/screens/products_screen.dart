import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<dynamic> _products = [];
  bool _loading = true;
  String? _error;
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await ApiService.getProducts();
      setState(() => _products = products);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showProductForm({Map<String, dynamic>? existing}) async {
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final stockController = TextEditingController(text: existing?['stock']?.toString() ?? '0');
    final buyPriceController = TextEditingController(
      text: existing != null ? existing['buy_price'].toString() : '',
    );
    final sellPriceController = TextEditingController(
      text: existing != null ? existing['sell_price'].toString() : '',
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? 'Tambah produk' : 'Edit produk',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama produk', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stok', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: buyPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga beli (Rp)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sellPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga jual (Rp)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                try {
                  if (existing == null) {
                    await ApiService.addProduct(
                      name: nameController.text.trim(),
                      stock: int.tryParse(stockController.text) ?? 0,
                      buyPrice: double.tryParse(buyPriceController.text) ?? 0,
                      sellPrice: double.tryParse(sellPriceController.text) ?? 0,
                    );
                  } else {
                    await ApiService.updateProduct(
                      existing['id'],
                      name: nameController.text.trim(),
                      stock: int.tryParse(stockController.text),
                      buyPrice: double.tryParse(buyPriceController.text),
                      sellPrice: double.tryParse(sellPriceController.text),
                    );
                  }
                  if (context.mounted) Navigator.of(context).pop(true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menyimpan: ${e.toString().replaceFirst('Exception: ', '')}')),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) _loadProducts();
  }

  Future<void> _deleteProduct(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text('"$name" akan dihapus permanen. Transaksi lama yang terkait produk ini tetap tersimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteProduct(id);
      _loadProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produk & stok')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadProducts, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : _products.isEmpty
              ? const Center(child: Text('Belum ada produk. Tambah produk pertamamu.'))
              : RefreshIndicator(
                  onRefresh: _loadProducts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final p = _products[index];
                      final stockLow = (p['stock'] as int? ?? 0) <= 5;
                      return Card(
                        child: ListTile(
                          title: Text(p['name']),
                          subtitle: Text(
                            'Stok: ${p['stock']} • Jual: ${_currencyFormat.format(double.parse(p['sell_price'].toString()))}',
                            style: stockLow ? const TextStyle(color: Colors.orange) : null,
                          ),
                          onTap: () => _showProductForm(existing: p),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteProduct(p['id'], p['name']),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
