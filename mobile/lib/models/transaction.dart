class TransactionModel {
  final String id;
  final String type; // 'masuk' atau 'keluar'
  final double amount;
  final String? note;
  final DateTime date;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    this.note,
    required this.date,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      type: json['type'],
      amount: double.parse(json['amount'].toString()),
      note: json['note'],
      date: DateTime.parse(json['transaction_date']),
    );
  }
}
