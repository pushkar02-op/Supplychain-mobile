// lib/screens/pdf_view_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../services/invoice_service.dart';

class PdfViewerScreen extends StatefulWidget {
  /// now takes an invoice ID
  final int invoiceId;
  const PdfViewerScreen({super.key, required this.invoiceId});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final path = await InvoiceService.downloadInvoicePdf(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        _localPath = path;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Invoice #${widget.invoiceId}')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(
                  'Error loading PDF:\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              )
              : PDFView(
                filePath: _localPath!,
                enableSwipe: true,
                swipeHorizontal: false,
                autoSpacing: true,
                pageFling: true,
                onError: (err) => debugPrint('PDFView error: $err'),
                onPageError:
                    (page, err) => debugPrint('Page $page error: $err'),
              ),
    );
  }
}
