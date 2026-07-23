import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  String _type = 'masuk';
  final _amountController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _noteController = TextEditingController();
  bool _saving = false;
  bool _loadingOptions = true;

  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  String? _selectedCategoryId;
  String? _selectedProductId;
  bool _amountManuallyEdited = false;
  bool _autoFilling = false;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(() => setState(_recalculateAmount));
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
    } catch (_) {
      // Kategori/produk opsional — form tetap bisa dipakai tanpa keduanya
    } finally {
      setState(() => _loadingOptions = false);
    }
  }

  List<dynamic> get _filteredCategories =>
      _categories.where((c) => c['type'] == _type).toList();

  dynamic get _selectedProduct {
    for (final p in _products) {
      if (p['id'] == _selectedProductId) return p;
    }
    return null;
  }

  bool get _selectedProductPriceIsZero {
    final product = _selectedProduct;
    if (product == null) return false;
    final priceField = _type == 'masuk' ? product['sell_price'] : product['buy_price'];
    final price = double.tryParse(priceField.toString()) ?? 0;
    return price <= 0;
  }

  // Hitung ulang jumlah (Rp) otomatis = harga produk x kuantitas.
  // Hanya jalan kalau user belum mengetik manual di field jumlah.
  void _recalculateAmount() {
    if (_amountManuallyEdited) return;
    final product = _selectedProduct;
    if (product == null) return;

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) return;

    final priceField = _type == 'masuk' ? product['sell_price'] : product['buy_price'];
    final price = double.tryParse(priceField.toString()) ?? 0;
    final total = price * quantity;

    _autoFilling = true;
    _amountController.text = total.toStringAsFixed(0);
    _autoFilling = false;
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
    if (_selectedProductId != null && (quantity == null || quantity <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah barang yang valid')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiService.addTransaction(
        type: _type,
        amount: amount,
        categoryId: _selectedCategoryId,
        productId: _selectedProductId,
        quantity: quantity,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catat transaksi')),
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
                      // Reset kategori kalau tidak cocok dengan tipe baru
                      if (_selectedCategoryId != null &&
                          !_filteredCategories.any((c) => c['id'] == _selectedCategoryId)) {
                        _selectedCategoryId = null;
                      }
                      _recalculateAmount();
                    }),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Kategori (opsional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tanpa kategori')),
                      ..._filteredCategories.map(
                        (c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name'])),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedCategoryId = value),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedProductId,
                    decoration: const InputDecoration(labelText: 'Produk (opsional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tanpa produk')),
                      ..._products.map(
                        (p) => DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text('${p['name']} (stok: ${p['stock']})'),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedProductId = value;
                      _amountManuallyEdited = false;
                      _recalculateAmount();
                    }),
                  ),
                  if (_selectedProductPriceIsZero) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _type == 'masuk'
                                ? 'Harga jual produk ini belum diisi. Isi "Jumlah (Rp)" manual, atau lengkapi harga di halaman Produk & stok.'
                                : 'Harga beli produk ini belum diisi. Isi "Jumlah (Rp)" manual, atau lengkapi harga di halaman Produk & stok.',
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
                      decoration: InputDecoration(
                        labelText: _type == 'masuk' ? 'Jumlah barang terjual' : 'Jumlah barang masuk (restock)',
                        border: const OutlineInputBorder(),
                        helperText: _type == 'masuk'
                            ? 'Stok akan berkurang otomatis'
                            : 'Stok akan bertambah otomatis',
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      if (!_autoFilling) _amountManuallyEdited = true;
                    },
                    decoration: InputDecoration(
                      labelText: 'Jumlah (Rp)',
                      border: const OutlineInputBorder(),
                      helperText: _selectedProductId != null && !_amountManuallyEdited
                          ? 'Dihitung otomatis dari harga produk × jumlah'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Simpan'),
                  ),
                ],
              ),
            ),
    );
  }
}
