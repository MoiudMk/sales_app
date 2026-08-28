class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final int productId;
  final String productName;
  final double price;
  final int quantity;

  InvoiceItem({
    this.id,
    this.invoiceId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'] as int?,
      invoiceId: map['invoiceId'] as int?,
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
    );
  }
}

class Invoice {
  final int? id;
  final String invoiceNumber;
  final DateTime date;
  final double discount;
  final String customerName;
  final List<InvoiceItem> items;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.date,
    this.discount = 0,
    this.customerName = 'عميل نقدي',
    this.items = const [],
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get total => subtotal - discount;
  int get itemsCount => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'date': date.toIso8601String(),
      'discount': discount,
      'customerName': customerName,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoiceNumber'] as String,
      date: DateTime.parse(map['date'] as String),
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      customerName: map['customerName'] as String? ?? 'عميل نقدي',
    );
  }
}
