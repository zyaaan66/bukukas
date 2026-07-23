import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late String _type;
  late TextEditingController _amountController;
  late TextEditingController _quantityController;
  late TextEditingController _noteController;

  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  String? _selectedCategoryId;
  String? _selectedProductId;
  bool _loadingOptions = true;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _type = t['type'];
    // PENTING: amount dari backend berupa string desimal (mis. "15000.00").
    // Format ulang jadi bilangan bulat murni supaya parsing saat simpan tidak keliru.
    final initialAmount = double.tryParse(t['amount'].toString()) ?? 0;
    _amountController = TextEditingController(text: initialAmount.toStringAsFixed(0));
    _quantityController = TextEditingController(text: (t['quantity'] ?? 1).toString());
    _noteController = TextEditingController(text: t['note'] ?? '');
    _selectedCategoryId = t['category_id'];
    _selectedProductId = t['product_id'];
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() => _loadingOptions = true);
    try {
      final categories = await ApiService.getCategories();
      final products = await ApiService.getProducts();
      setState(() {
        _categories = categories;
        _products = products;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loadingOptions = false);
    }
  }

  List<dynamic> get _filteredCategories => _categories.where((c) => c['type'] == _type).toList();

  bool get _selectedProductPriceIsZero {
    for (final p in _products) {
      if (p['id'] == _selectedProductId) {
        final priceField = _type == 'masuk' ? p['sell_price'] : p['buy_price'];
        final price = double.tryParse(priceField.toString()) ?? 0;
        return price <= 0;
      }
    }
    return false;
  }

  Future<void> _save() async {
    // Field jumlah hanya diisi angka polos (tanpa pemisah ribuan), jadi parse langsung.
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah yang valid')),
      );
      return;
    }
    final quantity = _selectedProductId != null ? int.tryParse(_quantityController.text) : null;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.updateTransaction(
        widget.transaction['id'],
        type: _type,
        amount: amount,
        categoryId: _selectedCategoryId,
        productId: _selectedProductId,
        quantity: quantity,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Transaksi ini akan dihapus permanen. Kalau terkait produk, stok akan dikembalikan seperti semula.'),
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

    setState(() => _deleting = true);
    try {
      await ApiService.deleteTransaction(widget.transaction['id']);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _deleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail transaksi'),
        actions: [
          IconButton(
            icon: _deleting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline),
            onPressed: _deleting ? null : _confirmDelete,
          ),
        ],
      ),
      body: _loadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'masuk', label: Text('Kas masuk')),
                      ButtonSegment(value: 'keluar', label: Text('Kas keluar')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() {
                      _type = s.first;
                      // Reset kategori kalau tidak cocok dengan tipe baru, supaya
                      // tidak diam-diam menyimpan kategori yang tipenya salah.
                      if (_selectedCategoryId != null &&
                          !_filteredCategories.any((c) => c['id'] == _selectedCategoryId)) {
                        _selectedCategoryId = null;
                      }
                    }),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _filteredCategories.any((c) => c['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
                    decoration: const InputDecoration(labelText: 'Kategori (opsional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tanpa kategori')),
                      ..._filteredCategories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']))),
                    ],
                    onChanged: (value) => setState(() => _selectedCategoryId = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedProductId,
                    decoration: const InputDecoration(labelText: 'Produk (opsional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tanpa produk')),
                      ..._products.map((p) => DropdownMenuItem(
                            value: p['id'] as String,
                            child: Text('${p['name']} (stok: ${p['stock']})'),
                          )),
                    ],
                    onChanged: (value) => setState(() => _selectedProductId = value),
                  ),
                  if (_selectedProductPriceIsZero) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Harga produk ini belum diisi. Pastikan "Jumlah (Rp)" sudah benar secara manual.',
                            style: const TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_selectedProductId != null) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Jumlah barang', border: OutlineInputBorder()),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Jumlah (Rp)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder()),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Simpan perubahan'),
                  ),
                ],
              ),
            ),
    );
  }
}
