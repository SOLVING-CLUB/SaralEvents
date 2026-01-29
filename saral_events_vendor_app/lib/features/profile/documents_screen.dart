import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/state/session.dart';
import '../vendor_setup/vendor_service.dart';
import '../vendor_setup/vendor_models.dart';
import '../../core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late Future<List<VendorDocument>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDocuments();
  }

  Future<List<VendorDocument>> _loadDocuments() async {
    final session = context.read<AppSession>();
    final vendorId = session.vendorProfile?.id;
    if (vendorId == null) return [];
    return VendorService().getVendorDocuments(vendorId);
  }

  Future<void> _refresh() async {
    final session = context.read<AppSession>();
    final vendorId = session.vendorProfile?.id;
    if (vendorId != null) {
      await VendorService().syncDocumentsFromStorage(vendorId);
    }
    setState(() {
      _future = _loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: FutureBuilder<List<VendorDocument>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load documents: ${snapshot.error}'));
          }
          final docs = snapshot.data ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No documents found'),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Refresh'),
                  )
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final d = docs[i];
                final isPdf = d.fileName.toLowerCase().endsWith('.pdf');
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPdf ? Colors.red.shade50 : Colors.green.shade50,
                      child: Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: isPdf ? Colors.red.shade400 : Colors.green.shade400),
                    ),
                    title: Text(d.documentType, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.black),
                      onPressed: () => _previewDocument(d),
                      tooltip: 'Preview',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _previewDocument(VendorDocument doc) {
    if (kIsWeb) {
      final uri = Uri.parse(doc.fileUrl);
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final isPdf = doc.fileName.toLowerCase().endsWith('.pdf');
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(doc.fileName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                  child: isPdf
                      ? _buildPdfViewer(doc.fileUrl)
                      : _buildPhotoViewer(doc.fileUrl),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoViewer(String url) {
    return PhotoView(
      imageProvider: NetworkImage(url),
      backgroundDecoration: const BoxDecoration(color: Colors.white),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3.0,
      loadingBuilder: (_, __) => const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, __, ___) => const Center(child: Text('Failed to load image')),
    );
  }

  Widget _buildPdfViewer(String url) {
    final controller = PdfControllerPinch(document: _loadPdf(url));
    return PdfViewPinch(controller: controller);
  }

  Future<PdfDocument> _loadPdf(String url) async {
    final uri = Uri.parse(url);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch PDF');
    }
    return PdfDocument.openData(res.bodyBytes);
  }
}
