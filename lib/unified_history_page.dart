
import 'dart:async';

import 'package:butterfly/shared/models/history_item.dart';
import 'package:butterfly/shared/models/history_type.dart';
import 'package:butterfly/shared/pages/share_editor_page.dart';
import 'package:butterfly/shared/services/history_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class UnifiedHistoryPage extends StatefulWidget {
  const UnifiedHistoryPage({Key? key}) : super(key: key);

  @override
  _UnifiedHistoryPageState createState() => _UnifiedHistoryPageState();
}

class _UnifiedHistoryPageState extends State<UnifiedHistoryPage> {
  bool _isRecording = false;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  String? _audioPath;
  List<HistoryItem> _historyItems = [];
  final _historyService = HistoryService();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final items = await _historyService.getHistoryItems();
    // A bit of a hack: In the old implementation, recordings were just file paths.
    // We will convert any old string-based recordings into the new HistoryItem format.
    // This is a simple migration. A real app might need a more robust migration strategy.
    final migratedItems = await _migrateOldRecordings(items);
    setState(() {
      _historyItems = migratedItems;
    });
  }

  Future<List<HistoryItem>> _migrateOldRecordings(List<HistoryItem> items) async {
    // This is a placeholder for migration logic.
    // For now, we assume the items are already in the new format.
    // A real implementation would check for old data and convert it.
    return items;
  }


  Future<void> _start() async {
    if (await Permission.microphone.request().isGranted) {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(const RecordConfig(), path: path);

      setState(() {
        _isRecording = true;
        _audioPath = path;
      });
    }
  }

  Future<void> _stop() async {
    await _audioRecorder.stop();
    if (_audioPath != null) {
      final newItem = HistoryItem(
        type: HistoryType.recording,
        creationDate: DateTime.now(),
        content: _audioPath!,
      );
      await _historyService.addHistoryItem(newItem);
      _loadHistory(); // Refresh the list
    }
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _play(String path) async {
    await _audioPlayer.play(DeviceFileSource(path));
  }

  void _onItemTapped(HistoryItem item) {
    if (item.type == HistoryType.recording) {
      _play(item.content);
    } else if (item.type == HistoryType.share) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShareEditorPage(item: item),
        ),
      ).then((_) => _loadHistory()); // Refresh list after editing
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: _historyItems.isEmpty
          ? const Center(child: Text('No history yet.'))
          : ListView.builder(
              itemCount: _historyItems.length,
              itemBuilder: (context, index) {
                final item = _historyItems[index];
                return ListTile(
                  leading: Icon(
                    item.type == HistoryType.recording
                        ? Icons.mic
                        : Icons.share,
                  ),
                  title: Text(
                    item.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.creationDate.toLocal().toString().substring(0, 16)}'
                    '${item.type == HistoryType.share && item.shareDetails?.sourceApp != null ? " via ${item.shareDetails!.sourceApp}" : ""}',
                  ),
                  onTap: () => _onItemTapped(item),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isRecording ? _stop : _start,
        child: Icon(_isRecording ? Icons.stop : Icons.mic),
      ),
    );
  }
}
