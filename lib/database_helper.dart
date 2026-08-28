import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/product.dart';
import '../models/invoice.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sales_app.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT,
        price REAL NOT NULL,
        cost REAL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0,
        category TEXT DEFAULT 'عام',
        lowStockThreshold INTEGER DEFAULT 5
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNumber TEXT NOT NULL,
        date TEXT NOT NULL,
        discount REAL DEFAULT 0,
        customerName TEXT DEFAULT 'عميل نقدي'
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        FOREIGN KEY (invoiceId) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');
  }

  // ---------------- Products ----------------

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return db.insert('products', product.toMap()..remove('id'));
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getProducts({String? search}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (search != null && search.trim().isNotEmpty) {
      maps = await db.query(
        'products',
        where: 'name LIKE ? OR barcode LIKE ?',
        whereArgs: ['%$search%', '%$search%'],
        orderBy: 'name ASC',
      );
    } else {
      maps = await db.query('products', orderBy: 'name ASC');
    }
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<void> adjustStock(int productId, int deltaQuantity) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE products SET quantity = quantity + ? WHERE id = ?',
      [deltaQuantity, productId],
    );
  }

  // ---------------- Invoices ----------------

  Future<int> createInvoiceWithItems(Invoice invoice) async {
    final db = await database;
    return db.transaction((txn) async {
      final invoiceId = await txn.insert('invoices', invoice.toMap()..remove('id'));
      for (final item in invoice.items) {
        await txn.insert('invoice_items', {
          'invoiceId': invoiceId,
          'productId': item.productId,
          'productName': item.productName,
          'price': item.price,
          'quantity': item.quantity,
        });
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
      return invoiceId;
    });
  }

  Future<List<Invoice>> getInvoices() async {
    final db = await database;
    final maps = await db.query('invoices', orderBy: 'date DESC');
    List<Invoice> invoices = [];
    for (final m in maps) {
      final invoice = Invoice.fromMap(m);
      final items = await getInvoiceItems(invoice.id!);
      invoices.add(Invoice(
        id: invoice.id,
        invoiceNumber: invoice.invoiceNumber,
        date: invoice.date,
        discount: invoice.discount,
        customerName: invoice.customerName,
        items: items,
      ));
    }
    return invoices;
  }

  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) async {
    final db = await database;
    final maps = await db.query('invoice_items',
        where: 'invoiceId = ?', whereArgs: [invoiceId]);
    return maps.map((m) => InvoiceItem.fromMap(m)).toList();
  }

  Future<Map<String, dynamic>> getTodaySummary() async {
    final db = await database;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT i.id, i.discount, ii.price, ii.quantity
      FROM invoices i
      JOIN invoice_items ii ON ii.invoiceId = i.id
      WHERE substr(i.date, 1, 10) = ?
    ''', [todayStr]);

    double totalSales = 0;
    Set<int> invoiceIds = {};
    Map<int, double> discountByInvoice = {};
    for (final row in result) {
      final price = (row['price'] as num).toDouble();
      final qty = row['quantity'] as int;
      totalSales += price * qty;
      final invId = row['id'] as int;
      invoiceIds.add(invId);
      discountByInvoice[invId] = (row['discount'] as num).toDouble();
    }
    final totalDiscount = discountByInvoice.values.fold(0.0, (a, b) => a + b);

    return {
      'totalSales': totalSales - totalDiscount,
      'invoiceCount': invoiceIds.length,
    };
  }
}
