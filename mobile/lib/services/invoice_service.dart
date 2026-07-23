import 'package:intl/intl.dart';
import 'api_service.dart';

class InvoiceService {
  static final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static final _dateFormat = DateFormat('d MMMM yyyy', 'id_ID');

  /// Menyusun teks invoice/struk sederhana dari satu transaksi.
  /// [transaction] diharapkan berasal dari hasil ApiService.getTransactions(),
  /// yang sudah menyertakan category_name & product_name dari backend.
  static Future<String> buildInvoiceText(Map<String, dynamic> transaction) async {
    final businessName = await ApiService.getBusinessName();
    final isMasuk = transaction['type'] == 'masuk';
    final amount = double.tryParse(transaction['amount'].toString()) ?? 0;
    final date = DateTime.tryParse(transaction['transaction_date'].toString()) ?? DateTime.now();

    final buffer = StringBuffer();
    buffer.writeln('*${businessName.isNotEmpty ? businessName : 'Nota Transaksi'}*');
    buffer.writeln(_dateFormat.format(date));
    buffer.writeln('—————————————————');

    if (transaction['product_name'] != null) {
      final qty = transaction['quantity'] ?? 1;
      buffer.writeln('${transaction['product_name']} x$qty');
    }
    if (transaction['category_name'] != null) {
      buffer.writeln('Kategori: ${transaction['category_name']}');
    }
    if (transaction['note'] != null && transaction['note'].toString().isNotEmpty) {
      buffer.writeln('Catatan: ${transaction['note']}');
    }

    buffer.writeln('—————————————————');
    buffer.writeln('${isMasuk ? 'Total diterima' : 'Total dibayar'}: *${_currencyFormat.format(amount)}*');
    buffer.writeln();
    buffer.writeln('Dibuat dengan BukuKas Pintar');

    return buffer.toString();
  }
}
