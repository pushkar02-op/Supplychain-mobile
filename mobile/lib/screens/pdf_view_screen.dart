// lib/screens/pdf_view_screen.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mart_bill.dart';
import '../providers/mart_bill_provider.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_snack_bar.dart';
import '../ui/widgets/agro_status_badge.dart';

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
      return AgroErrorState.loadFailed(
        customTitle: 'Error loading PDF',
        message: _error,
        onRetry: _loadData,
      );
    }

    if (_localPath != null) {
      return Column(
        children: [
          if (_bill?.status == 'VERIFIED')
            Container(
              width: double.infinity,
              color: AgroColors.success.background,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.lock, size: 16, color: AgroColors.success.text),
                  const SizedBox(width: 8),
                  Text(
                    'This bill is verified and locked.',
                    style: TextStyle(
                      color: AgroColors.success.text,
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

    return const AgroErrorState.general(
      customTitle: 'Unexpected state',
      message: 'PDF state could not be resolved.',
    );
  }

  Widget _buildStatusBadge(String status) {
    return AgroStatusBadge.fromBillStatus(status, size: AgroStatusBadgeSize.compact);
  }
}
