
import 'package:butterfly/shared/models/history_item.dart';
import 'package:butterfly/shared/services/history_service.dart';
import 'package:flutter/material.dart';

class ShareEditorPage extends StatefulWidget {
  final HistoryItem item;

  const ShareEditorPage({Key? key, required this.item}) : super(key: key);

  @override
  _ShareEditorPageState createState() => _ShareEditorPageState();
}

class _ShareEditorPageState extends State<ShareEditorPage> {
  late TextEditingController _contentController;
  final HistoryService _historyService = HistoryService();

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.item.content);
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _save() async {
    final newContent = _contentController.text;
    if (newContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content cannot be empty.')),
      );
      return;
    }

    final newItem = HistoryItem(
      id: widget.item.id,
      type: widget.item.type,
      creationDate: widget.item.creationDate,
      content: newContent,
      shareDetails: widget.item.shareDetails, // Preserve original share details
    );

    if (newItem.id != null) {
      await _historyService.updateHistoryItem(newItem);
    } else {
      await _historyService.addHistoryItem(newItem);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved!')),
    );

    // Pop twice if coming from a share intent, once if editing existing.
    // A more robust navigation solution might be needed for complex scenarios.
    if (Navigator.canPop(context)) {
       Navigator.pop(context, true); // Pop editor page
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit & Save'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.item.shareDetails?.sourceApp != null)
              Text(
                'From: ${widget.item.shareDetails!.sourceApp}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (widget.item.shareDetails?.url != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Text(
                  'URL: ${widget.item.shareDetails!.url}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Edit your content...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
