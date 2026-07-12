import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/word_entry.dart';
import '../services/history_service.dart';
import 'pdf_reader_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = HistoryService();
  late Future<List<GeneratedBook>> _books;

  @override
  void initState() {
    super.initState();
    _books = _service.load();
  }

  Future<void> _export(GeneratedBook book) async {
    final output = await FilePicker.saveFile(
      dialogTitle: 'Export Lexora PDF',
      fileName: book.title,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (output == null) return;
    await File(book.path).copy(output);
  }

  Future<void> _share(GeneratedBook book) async {
    await Share.shareXFiles(
      [XFile(book.path, mimeType: 'application/pdf')],
      subject: 'Lexora vocabulary book',
    );
  }

  Future<void> _delete(GeneratedBook book) async {
    await _service.remove(book.id);
    final file = File(book.path);
    if (await file.exists()) await file.delete();
    setState(() => _books = _service.load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('History', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Read, export, or share your generated vocabulary books.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 22),
              Expanded(
                child: FutureBuilder<List<GeneratedBook>>(
                  future: _books,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final books = snapshot.data ?? const [];
                    if (books.isEmpty) {
                      return const Center(child: Text('Your generated PDFs will appear here.'));
                    }
                    return ListView.separated(
                      itemCount: books.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                            leading: Container(
                              width: 44,
                              height: 52,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.picture_as_pdf_rounded, color: theme.colorScheme.primary),
                            ),
                            title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${book.wordCount} words · ${_formatDate(book.createdAt)}'),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => PdfReaderScreen(book: book)),
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'More actions',
                              onSelected: (action) {
                                if (action == 'export') _export(book);
                                if (action == 'share') _share(book);
                                if (action == 'delete') _delete(book);
                              },
                              itemBuilder: (context) => [
                                if (!Platform.isAndroid)
                                  const PopupMenuItem(value: 'export', child: Text('Export to…')),
                                const PopupMenuItem(value: 'share', child: Text('Share…')),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}'
        ' ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
