class Product {
  final int? id;
  final String name;
  final String barcode;
  final double price; // سعر البيع
  final double cost; // سعر التكلفة
  final int quantity; // الكمية بالمخزون
  final String category;
  final int lowStockThreshold;

  Product({
    this.id,
    required this.name,
    this.barcode = '',
    required this.price,
    this.cost = 0,
    required this.quantity,
    this.category = 'عام',
    this.lowStockThreshold = 5,
  });

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    double? price,
    double? cost,
    int? quantity,
    String? category,
    int? lowStockThreshold,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'cost': cost,
      'quantity': quantity,
      'category': category,
      'lowStockThreshold': lowStockThreshold,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      barcode: map['barcode'] as String? ?? '',
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      quantity: map['quantity'] as int,
      category: map['category'] as String? ?? 'عام',
      lowStockThreshold: map['lowStockThreshold'] as int? ?? 5,
    );
  }

  bool get isLowStock => quantity <= lowStockThreshold;
}
