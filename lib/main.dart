import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'record_page.dart';
import 'audio_player_page.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '文件浏览与录音',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const FileListPage(),
    );
  }
}

class FileListPage extends StatefulWidget {
  const FileListPage({super.key});

  @override
  State<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends State<FileListPage> {
  List<FileSystemEntity> files = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      loading = true;
    });
    Directory dir = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> fileList = dir.listSync();
    setState(() {
      files = fileList;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全部文件')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final stat = file.statSync();
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(file.path.split(Platform.pathSeparator).last),
                  subtitle: Text(stat.modified.toString()),
                  onTap: () async {
                    // 自动查找并加载波形数据
                    final waveFile = File(file.path + '.wave.json');
                    List<double> waveform = [];
                    if (await waveFile.exists()) {
                      final content = await waveFile.readAsString();
                      final data = jsonDecode(content);
                      waveform = List<double>.from(
                        data.map((e) => (e as num).toDouble()),
                      );
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AudioPlayerPage(
                          filePath: file.path,
                          waveform: waveform,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RecordPage()),
          );
        },
        child: const Icon(Icons.mic),
      ),
    );
  }
}
