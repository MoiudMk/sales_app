import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/invoice.dart';
import '../services/pdf_invoice_service.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<Invoice> _invoices = [];
  bool _loading = true;
  final _currency = NumberFormat.currency(locale: 'ar', symbol: 'ر.س', decimalDigits: 2);
  final _dateFormat = DateFormat('yyyy/MM/dd - hh:mm a', 'ar');
  String? _processingInvoiceNumber;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final invoices = await DatabaseHelper.instance.getInvoices();
    setState(() {
      _invoices = invoices;
      _loading = false;
    });
  }

  Future<void> _print(Invoice invoice) async {
    setState(() => _processingInvoiceNumber = invoice.invoiceNumber);
    try {
      await PdfInvoiceService.printInvoice(invoice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّرت الطباعة. تأكد من اتصال الإنترنت عند أول استخدام (لتحميل الخط العربي).')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingInvoiceNumber = null);
    }
  }

  Future<void> _share(Invoice invoice) async {
    setState(() => _processingInvoiceNumber = invoice.invoiceNumber);
    try {
      await PdfInvoiceService.shareInvoice(invoice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تصدير الملف. تأكد من اتصال الإنترنت عند أول استخدام (لتحميل الخط العربي).')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingInvoiceNumber = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الفواتير')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(child: Text('لا توجد فواتير بعد', style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _invoices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final invoice = _invoices[i];
                      return Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: ExpansionTile(
                          title: Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${invoice.customerName} • ${_dateFormat.format(invoice.date)}'),
                          trailing: Text(
                            _currency.format(invoice.total),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          children: [
                            ...invoice.items.map((item) => ListTile(
                                  dense: true,
                                  title: Text(item.productName),
                                  subtitle: Text('${item.quantity} × ${_currency.format(item.price)}'),
                                  trailing: Text(_currency.format(item.subtotal)),
                                )),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('الإجمالي الفرعي'),
                                      Text(_currency.format(invoice.subtotal)),
                                    ],
                                  ),
                                  if (invoice.discount > 0) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('الخصم'),
                                        Text('- ${_currency.format(invoice.discount)}'),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(_currency.format(invoice.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _processingInvoiceNumber == invoice.invoiceNumber
                                              ? null
                                              : () => _print(invoice),
                                          icon: _processingInvoiceNumber == invoice.invoiceNumber
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : const Icon(Icons.print_outlined, size: 18),
                                          label: const Text('طباعة'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: _processingInvoiceNumber == invoice.invoiceNumber
                                              ? null
                                              : () => _share(invoice),
                                          icon: const Icon(Icons.ios_share, size: 18),
                                          label: const Text('تصدير PDF'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
