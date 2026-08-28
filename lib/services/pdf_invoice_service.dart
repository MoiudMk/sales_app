import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';

class PdfInvoiceService {
  static final _currency = NumberFormat.currency(locale: 'ar', symbol: 'ر.س', decimalDigits: 2);
  static final _dateFormat = DateFormat('yyyy/MM/dd - hh:mm a', 'ar');

  static Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
    final doc = pw.Document();

    // خط عربي يُحمَّل عبر Google Fonts (يحتاج إنترنت أول مرة ثم يُخزَّن على الجهاز)
    final arabicFont = await PdfGoogleFonts.notoSansArabicRegular();
    final arabicBold = await PdfGoogleFonts.notoSansArabicBold();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text('فاتورة مبيعات',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('رقم الفاتورة: ${invoice.invoiceNumber}'),
                  pw.Text('التاريخ: ${_dateFormat.format(invoice.date)}'),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text('العميل: ${invoice.customerName}'),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('الصنف', bold: true),
                      _cell('الكمية', bold: true),
                      _cell('السعر', bold: true),
                      _cell('الإجمالي', bold: true),
                    ],
                  ),
                  ...invoice.items.map(
                    (item) => pw.TableRow(
                      children: [
                        _cell(item.productName),
                        _cell('${item.quantity}'),
                        _cell(_currency.format(item.price)),
                        _cell(_currency.format(item.subtotal)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.SizedBox(
                  width: 220,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _summaryRow('الإجمالي الفرعي', _currency.format(invoice.subtotal)),
                      if (invoice.discount > 0)
                        _summaryRow('الخصم', '- ${_currency.format(invoice.discount)}'),
                      pw.Divider(color: PdfColors.grey400),
                      _summaryRow('الإجمالي النهائي', _currency.format(invoice.total), bold: true),
                    ],
                  ),
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.Center(
                child: pw.Text('شكرًا لتعاملكم معنا',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  /// يفتح معاينة/حوار الطباعة مباشرة (يدعم الطباعة اللاسلكية والحفظ كـ PDF)
  static Future<void> printInvoice(Invoice invoice) async {
    final bytes = await generateInvoicePdf(invoice);
    await Printing.layoutPdf(onLayout: (format) async => bytes, name: invoice.invoiceNumber);
  }

  /// يصدّر الفاتورة كملف PDF ويفتح قائمة المشاركة (واتساب، إيميل، حفظ...)
  static Future<void> shareInvoice(Invoice invoice) async {
    final bytes = await generateInvoicePdf(invoice);
    await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNumber}.pdf');
  }
}
