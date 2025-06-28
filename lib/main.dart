import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
      title: '录音播放器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
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
    try {
      Directory dir = await getApplicationDocumentsDirectory();
      List<FileSystemEntity> fileList = dir.listSync();
      // 只显示音频文件
      List<FileSystemEntity> audioFiles = fileList.where((file) {
        String fileName = file.path.toLowerCase();
        return fileName.endsWith('.aac') ||
            fileName.endsWith('.m4a') ||
            fileName.endsWith('.wav') ||
            fileName.endsWith('.mp3');
      }).toList();
      
      // 按修改时间排序，最新的在前面
      audioFiles.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      
      setState(() {
        files = audioFiles;
        loading = false;
      });
    } catch (e) {
      setState(() {
        files = [];
        loading = false;
      });
    }
  }

  Future<void> _renameFile(FileSystemEntity file) async {
    final currentName = file.path.split(Platform.pathSeparator).last;
    final nameWithoutExt = currentName.substring(
      0,
      currentName.lastIndexOf('.'),
    );
    final extension = currentName.substring(currentName.lastIndexOf('.'));

    final textController = TextEditingController(text: nameWithoutExt);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '重命名文件',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '文件名',
            hintText: '请输入新的文件名',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, textController.text);
            },
            child: const Text(
              '确定',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != nameWithoutExt) {
      try {
        final newPath = '${file.parent.path}/$newName$extension';
        final newFile = File(newPath);

        // 重命名主文件
        await file.rename(newPath);

        // 重命名相关文件
        final oldWaveFile = File('${file.path}.wave.json');
        final newWaveFile = File('$newPath.wave.json');
        if (await oldWaveFile.exists()) {
          await oldWaveFile.rename(newWaveFile.path);
        }

        final oldMarksFile = File('${file.path}.marks.json');
        final newMarksFile = File('$newPath.marks.json');
        if (await oldMarksFile.exists()) {
          await oldMarksFile.rename(newMarksFile.path);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('文件重命名成功'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadFiles();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重命名失败: $e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          '删除文件',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '确定要删除文件 "${file.path.split(Platform.pathSeparator).last}" 吗？',
          style: const TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              '删除',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 删除主文件
        await file.delete();

        // 删除相关文件
        final waveFile = File('${file.path}.wave.json');
        if (await waveFile.exists()) {
          await waveFile.delete();
        }

        final marksFile = File('${file.path}.marks.json');
        if (await marksFile.exists()) {
          await marksFile.delete();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('文件删除成功'),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadFiles();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<String> _getAudioDuration(String filePath) async {
    try {
      // 尝试从波形文件获取时长信息
      final waveFile = File('$filePath.wave.json');
      if (await waveFile.exists()) {
        final content = await waveFile.readAsString();
        final data = jsonDecode(content);
        final waveform = List<double>.from(
          data.map((e) => (e as num).toDouble()),
        );

        // 根据波形数据长度估算时长（每秒16个数据点）
        final estimatedSeconds = (waveform.length / 16).round();
        return _formatDuration(estimatedSeconds);
      }

      // 如果没有波形文件，返回默认时长
      return '未知时长';
    } catch (e) {
      print('获取音频时长失败: $e');
      return '未知时长';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '录音文件',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              onRefresh: _loadFiles,
              color: Colors.black,
              child: files.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mic_off,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '暂无录音文件',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '点击下方按钮开始录音',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        final stat = file.statSync();
                        final fileNameWithExt = file.path
                            .split(Platform.pathSeparator)
                            .last;
                        // 移除扩展名
                        final fileName = fileNameWithExt.substring(
                          0,
                          fileNameWithExt.lastIndexOf('.'),
                        );
                        final modifiedTime = stat.modified;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Slidable(
                            endActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (_) => _renameFile(file),
                                  backgroundColor: Colors.blue[600]!,
                                  foregroundColor: Colors.white,
                                  icon: Icons.edit,
                                  label: '重命名',
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(12),
                                  ),
                                ),
                                SlidableAction(
                                  onPressed: (_) => _deleteFile(file),
                                  backgroundColor: Colors.red[600]!,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete,
                                  label: '删除',
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(12),
                                  ),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.audiotrack,
                                    color: Colors.grey[600],
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  fileName,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    FutureBuilder<String>(
                                      future: _getAudioDuration(file.path),
                                      builder: (context, snapshot) {
                                        final duration =
                                            snapshot.data ?? '未知时长';
                                        return Text(
                                          '时长: $duration',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '创建时间: ${modifiedTime.toString().substring(0, 19)}',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Icon(
                                  Icons.play_arrow,
                                  color: Colors.grey[400],
                                  size: 24,
                                ),
                                onTap: () async {
                                  // 自动查找并加载波形数据
                                  final waveFile = File(
                                    '${file.path}.wave.json',
                                  );
                                  List<double> waveform = [];

                                  try {
                                    if (await waveFile.exists()) {
                                      final content = await waveFile
                                          .readAsString();
                                      final data = jsonDecode(content);
                                      waveform = List<double>.from(
                                        data.map((e) => (e as num).toDouble()),
                                      );
                                      print('成功加载波形数据，长度: ${waveform.length}');
                                    } else {
                                      print('波形文件不存在: ${waveFile.path}');
                                      // 生成默认波形数据
                                      waveform = List.generate(
                                        200, // 调整默认数据量，假设10秒音频，每秒20个数据
                                        (index) =>
                                            (0.2 + 0.4 * (index % 10) / 10.0)
                                                .toDouble(),
                                      );
                                      print('已生成默认波形数据');
                                    }
                                  } catch (e) {
                                    print('加载波形数据时出错: $e');
                                    // 生成默认波形数据
                                    waveform = List.generate(
                                      200, // 调整默认数据量，假设10秒音频，每秒20个数据
                                      (index) =>
                                          (0.2 + 0.4 * (index % 10) / 10.0)
                                              .toDouble(),
                                    );
                                    print('已生成默认波形数据作为备用');
                                  }

                                  if (mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AudioPlayerPage(
                                          filePath: file.path,
                                          waveform: waveform,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RecordPage()),
            );
            // 录音完成后刷新文件列表
            _loadFiles();
          },
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          child: const Icon(Icons.mic, size: 28),
        ),
      ),
    );
  }
}
