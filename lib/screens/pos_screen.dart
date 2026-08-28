import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/product.dart';
import '../models/invoice.dart';
import '../services/pdf_invoice_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String _search = '';

  // productId -> quantity in cart
  final Map<int, int> _cart = {};

  final _currency = NumberFormat.currency(locale: 'ar', symbol: 'ر.س', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products = await DatabaseHelper.instance.getProducts(search: _search);
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  void _addToCart(Product p) {
    final currentInCart = _cart[p.id] ?? 0;
    if (currentInCart >= p.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الكمية المتاحة من "${p.name}" غير كافية')),
      );
      return;
    }
    setState(() => _cart[p.id!] = currentInCart + 1);
  }

  void _decreaseFromCart(Product p) {
    final currentInCart = _cart[p.id] ?? 0;
    if (currentInCart <= 1) {
      setState(() => _cart.remove(p.id));
    } else {
      setState(() => _cart[p.id!] = currentInCart - 1);
    }
  }

  double get _cartTotal {
    double total = 0;
    for (final entry in _cart.entries) {
      final product = _products.firstWhere((p) => p.id == entry.key, orElse: () => Product(name: '', price: 0, quantity: 0));
      total += product.price * entry.value;
    }
    return total;
  }

  int get _cartItemsCount => _cart.values.fold(0, (a, b) => a + b);

  Future<void> _openCheckout() async {
    if (_cart.isEmpty) return;
    final items = _cart.entries.map((e) {
      final product = _products.firstWhere((p) => p.id == e.key);
      return InvoiceItem(productId: product.id!, productName: product.name, price: product.price, quantity: e.value);
    }).toList();

    final savedInvoice = await showModalBottomSheet<Invoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CheckoutSheet(items: items, subtotal: _cartTotal),
    );

    if (savedInvoice != null) {
      setState(() => _cart.clear());
      _load();
      if (mounted) _showPostCheckoutActions(savedInvoice);
    }
  }

  Future<void> _showPostCheckoutActions(Invoice invoice) async {
    bool processing = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> handle(Future<void> Function(Invoice) action) async {
              setSheetState(() => processing = true);
              try {
                await action(invoice);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذّرت العملية. تأكد من الإنترنت عند أول استخدام لتحميل الخط العربي.')),
                  );
                }
              } finally {
                setSheetState(() => processing = false);
              }
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('تم إنشاء الفاتورة بنجاح', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(invoice.invoiceNumber, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: processing ? null : () => handle(PdfInvoiceService.printInvoice),
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('طباعة'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: processing ? null : () => handle(PdfInvoiceService.shareInvoice),
                          icon: const Icon(Icons.ios_share),
                          label: const Text('تصدير PDF'),
                        ),
                      ),
                    ],
                  ),
                  if (processing) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('تخطي'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نقطة البيع'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث أو امسح باركود المنتج',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) {
                _search = v;
                _load();
              },
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(child: Text('لا توجد منتجات. أضف منتجات أولًا.', style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, i) {
                    final p = _products[i];
                    final inCart = _cart[p.id] ?? 0;
                    final outOfStock = p.quantity <= 0;
                    return Card(
                      elevation: 0,
                      color: inCart > 0
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: outOfStock ? null : () => _addToCart(p),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                outOfStock ? 'غير متوفر' : 'المتاح: ${p.quantity}',
                                style: TextStyle(fontSize: 12, color: outOfStock ? Colors.red : Colors.grey),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_currency.format(p.price), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  if (inCart > 0)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(onTap: () => _decreaseFromCart(p), child: const Icon(Icons.remove_circle_outline, size: 20)),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Text('$inCart', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                        InkWell(onTap: outOfStock ? null : () => _addToCart(p), child: const Icon(Icons.add_circle_outline, size: 20)),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: _cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _openCheckout,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('إتمام البيع • $_cartItemsCount قطعة'),
                      Text(_currency.format(_cartTotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class CheckoutSheet extends StatefulWidget {
  final List<InvoiceItem> items;
  final double subtotal;
  const CheckoutSheet({super.key, required this.items, required this.subtotal});

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  final _discountCtrl = TextEditingController(text: '0');
  final _customerCtrl = TextEditingController(text: 'عميل نقدي');
  final _currency = NumberFormat.currency(locale: 'ar', symbol: 'ر.س', decimalDigits: 2);
  bool _saving = false;

  double get _discount => double.tryParse(_discountCtrl.text) ?? 0;
  double get _total => (widget.subtotal - _discount).clamp(0, double.infinity);

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final invoice = Invoice(
      invoiceNumber: invoiceNumber,
      date: DateTime.now(),
      discount: _discount,
      customerName: _customerCtrl.text.trim().isEmpty ? 'عميل نقدي' : _customerCtrl.text.trim(),
      items: widget.items,
    );
    final invoiceId = await DatabaseHelper.instance.createInvoiceWithItems(invoice);
    if (mounted) {
      Navigator.pop(
        context,
        Invoice(
          id: invoiceId,
          invoiceNumber: invoice.invoiceNumber,
          date: invoice.date,
          discount: invoice.discount,
          customerName: invoice.customerName,
          items: invoice.items,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إتمام الفاتورة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  itemBuilder: (context, i) {
                    final item = widget.items[i];
                    return ListTile(
                      dense: true,
                      title: Text(item.productName),
                      subtitle: Text('${item.quantity} × ${_currency.format(item.price)}'),
                      trailing: Text(_currency.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
              const Divider(),
              TextField(
                controller: _customerCtrl,
                decoration: const InputDecoration(labelText: 'اسم العميل', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'الخصم', border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي الفرعي'),
                  Text(_currency.format(widget.subtotal)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي النهائي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_currency.format(_total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _confirm,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('تأكيد وحفظ الفاتورة'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
