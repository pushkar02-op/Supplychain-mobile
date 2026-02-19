// lib/screens/pdf_view_screen.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mart_bill.dart';
import '../providers/mart_bill_provider.dart';
import '../ui/widgets/agro_snack_bar.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  final int invoiceId;
  const PdfViewerScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  String? _localPath;
  MartBill? _bill;
  bool _loading = true;
  String? _error;
  bool _isMissingFile = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _isMissingFile = false;
    });

    try {
      final notifier = ref.read(martBillProvider.notifier);
      final bill = await notifier.getBillById(widget.invoiceId);

      final path = await notifier.downloadPdf(widget.invoiceId);

      if (!mounted) return;
      setState(() {
        _bill = bill;
        _localPath = path;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _loading = false;
        _error = msg;
        // Check for specific backend 404 message about missing file
        if (msg.contains('Mart bill file not found on server') ||
            msg.contains('404')) {
          _isMissingFile = true;
        }
      });
    }
  }

  Future<void> _handleReupload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _loading = true);
        await ref
            .read(martBillProvider.notifier)
            .replacePdf(widget.invoiceId, result.files.single.path!);

        if (!mounted) return;
        AgroSnackBar.success(context, 'File re-uploaded successfully!');
        // Reload data
        _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AgroSnackBar.error(context, 'Re-upload failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mart Bill #${widget.invoiceId}'),
        actions: [
          if (_bill != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: _buildStatusBadge(_bill!.status),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isMissingFile) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              const Text(
                'Original PDF Missing',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'The PDF file for this bill is missing from the server.\n'
                'This happens if the file was deleted or the server storage was reset.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _handleReupload,
                icon: const Icon(Icons.upload_file),
                label: const Text('Re-upload PDF'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading PDF:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_localPath != null) {
      return Column(
        children: [
          if (_bill?.status == 'VERIFIED')
            Container(
              width: double.infinity,
              color: Colors.green.shade100,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'This bill is verified and locked.',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PDFView(
              filePath: _localPath!,
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              onError: (err) => debugPrint('PDFView error: $err'),
              onPageError: (page, err) => debugPrint('Page $page error: $err'),
            ),
          ),
        ],
      );
    }

    return const Center(child: Text("Unexpected state"));
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'VERIFIED':
        color = Colors.green;
        break;
      case 'NEEDS_REVIEW':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(
        status,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
